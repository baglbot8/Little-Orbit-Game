class_name OrbitAtmosphere
extends Node3D
## Standalone atmosphere; all resources are procedural and stay in memory.
## Assign make_sky() to an Environment using BG_SKY. Existing ambient lighting
## remains the caller's choice. The sky material exposes nebula_strength and
## star_strength (set the latter to 0 if retaining a separate star backdrop).
## Add this node at the world root, configure(CENTERS, RADII), then call
## animate(elapsed, delta). Positions/directions use this node's local space.
## Optional wish(origin, up) advances itself, even without calls to animate().

const FIREFLY_COUNT := 28
const MAX_WISHES := 4
const TRAIL_POINTS := 12
const WISH_DURATION := 2.6
const TRAIL_DELAY := 0.042

const SKY_SHADER := """
shader_type sky;
render_mode disable_fog;

uniform vec3 navy : source_color = vec3(0.055, 0.086, 0.157);
uniform vec3 teal : source_color = vec3(0.102, 0.212, 0.247);
uniform vec3 violet : source_color = vec3(0.165, 0.145, 0.271);
uniform float nebula_strength : hint_range(0.0, 1.5) = 0.85;
uniform float star_strength : hint_range(0.0, 1.5) = 0.8;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec3 hash_point(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float cloud_noise(vec3 p) {
	vec3 c = floor(p);
	vec3 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(mix(hash3(c), hash3(c + vec3(1,0,0)), f.x),
		mix(hash3(c + vec3(0,1,0)), hash3(c + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(c + vec3(0,0,1)), hash3(c + vec3(1,0,1)), f.x),
		mix(hash3(c + vec3(0,1,1)), hash3(c + vec3(1,1,1)), f.x), f.y), f.z);
}

vec3 nebula(vec3 d) {
	// Direction-space noise avoids a panorama seam and pinched polar clouds.
	float broad = cloud_noise(d * 2.4 + vec3(8.1, 3.7, 2.5));
	float folds = cloud_noise(d * 5.3 + vec3(1.4, 7.9, 5.2));
	float wisps = cloud_noise(d * 10.7 + vec3(9.2, 1.3, 4.6));
	float cloud = broad * 0.61 + folds * 0.29 + wisps * 0.10;
	float latitude = dot(d, normalize(vec3(0.34, 0.83, -0.44)));
	float bend = (broad - 0.5) * 0.42 + (folds - 0.5) * 0.08;
	float ribbon_distance = (latitude + bend + 0.10) * 2.65;
	float veil_distance = (latitude + bend - 0.31) * 3.1;
	float ribbon = exp(-ribbon_distance * ribbon_distance);
	float veil = exp(-veil_distance * veil_distance);
	float patch = smoothstep(0.20, 0.82, cloud);
	float color_drift = 0.5 + 0.5 * sin(dot(d, vec3(2.1, -0.8, 1.5)) + 0.6);
	vec3 color = navy * (0.88 + 0.18 * broad);
	color = mix(color, teal, clamp(ribbon * patch * (0.40 + 0.40 * color_drift)
		* nebula_strength, 0.0, 1.0));
	color = mix(color, violet, clamp(veil * (0.18 + 0.43 * patch)
		* (1.0 - 0.45 * color_drift) * nebula_strength, 0.0, 1.0));
	// A low-contrast dust fold gives the broad bands some depth.
	float dust_distance = (latitude + bend + 0.025) * 9.0;
	float dust = exp(-dust_distance * dust_distance);
	return color * (1.0 - dust * (1.0 - patch) * 0.12 * nebula_strength);
}

vec3 star_layer(vec3 d, float density, vec3 offset, float keep, float brightness) {
	// Small spheres in a hashed 3D lattice intersect the viewing sphere.
	// Stars sit away from cell boundaries: no longitude seam or grid edges.
	vec3 p = d * density + offset;
	vec3 cell = floor(p);
	vec3 seed = hash_point(cell);
	vec3 center = vec3(0.25) + seed * 0.5;
	float distance_to_star = length(fract(p) - center);
	float radius = mix(0.072, 0.145, seed.z * seed.z);
	float aa = clamp(length(fwidth(p)) * 0.42, 0.008, 0.10);
	float core = 1.0 - smoothstep(max(0.0, radius - aa), radius + aa, distance_to_star);
	float visible = step(1.0 - keep, hash3(cell + vec3(17.7, 39.1, 11.3)));
	float luminance = mix(0.22, 0.85, pow(seed.y, 3.0)) * brightness;
	vec3 tint = mix(vec3(0.69, 0.82, 1.0), vec3(1.0, 0.90, 0.73), seed.x);
	return tint * core * visible * luminance;
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		// Bake only the diffuse bands. No TIME, POSITION, lights or animated
		// uniforms: the radiance map can stay cached, without glitter in IBL.
		COLOR = nebula(EYEDIR);
	} else {
		vec3 color = texture(RADIANCE, EYEDIR).rgb;
		// Stars remain full resolution while the soft clouds use the cubemap.
		vec3 stars = star_layer(EYEDIR, 108.0, vec3(23.1, 7.2, 41.8), 0.052, 0.55);
		stars += star_layer(EYEDIR, 57.0, vec3(5.4, 31.7, 12.8), 0.047, 1.0);
		COLOR = color + stars * star_strength;
	}
}
"""

const MOTE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled,
	skip_vertex_transform, fog_disabled;

varying float star_shape;

void vertex() {
	// Camera-facing quads, retaining each MultiMesh instance's own size.
	vec3 center = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	VERTEX = center + vec3(VERTEX.xy * size, 0.0);
	star_shape = INSTANCE_CUSTOM.r;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	float edge = 1.0 - smoothstep(0.65, 1.0, r2);
	float glow = exp(-r2 * 22.0) + 0.12 * exp(-r2 * 4.5);
	float rays = exp(-abs(p.x) * 32.0 - abs(p.y) * 4.0)
		+ exp(-abs(p.y) * 32.0 - abs(p.x) * 4.0);
	ALBEDO = COLOR.rgb;
	ALPHA = clamp((glow + rays * star_shape * 0.30) * edge * COLOR.a, 0.0, 1.0);
}
"""

var _flies: Array[Dictionary] = []
var _wishes: Array[Dictionary] = []
var _luma_center := Vector3.ZERO
var _luma_radius := 7.5
var _firefly_draw: MultiMeshInstance3D
var _wish_draw: MultiMeshInstance3D
var _mote_material: ShaderMaterial


## A fresh, independent Sky. Does not mutate an Environment or allocate nodes.
static func make_sky() -> Sky:
	var shader := Shader.new()
	shader.code = SKY_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	var sky := Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	return sky


func _init() -> void:
	set_process(false)


func _ready() -> void:
	set_process(not _wishes.is_empty())


## Reusable setup. Index 1 is Luma; absent/invalid Luma means no fireflies.
## Reconfiguration also clears any transient wishes from the previous layout.
func configure(centers: Array, radii: Array) -> void:
	_flies.clear()
	_wishes.clear()
	set_process(false)
	if is_instance_valid(_firefly_draw):
		_firefly_draw.visible = false
	if is_instance_valid(_wish_draw):
		_wish_draw.visible = false
		_wish_draw.multimesh.visible_instance_count = 0
	if centers.size() < 2 or radii.size() < 2 or not centers[1] is Vector3:
		return
	if not (radii[1] is float or radii[1] is int):
		return
	var center: Vector3 = centers[1]
	var radius := float(radii[1])
	if not center.is_finite() or not is_finite(radius) or radius <= 0.0:
		return
	_luma_center = center
	_luma_radius = radius
	if not is_instance_valid(_firefly_draw):
		_firefly_draw = _make_motes("LumaFireflies", FIREFLY_COUNT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 18473
	for i in range(FIREFLY_COUNT):
		# Even sphere coverage, with small deterministic variations per mote.
		var y := 1.0 - 2.0 * (float(i) + 0.5) / float(FIREFLY_COUNT)
		var angle := float(i) * 2.39996323
		var ring := sqrt(maxf(0.0, 1.0 - y * y))
		var up := Vector3(cos(angle) * ring, y, sin(angle) * ring)
		var frame := _surface_frame(up)
		_flies.append({
			"up": up, "right": frame.x, "forward": frame.z,
			"phase": rng.randf_range(0.0, TAU), "speed": rng.randf_range(0.27, 0.46),
			"height": rng.randf_range(0.35, 0.85), "size": rng.randf_range(0.18, 0.28),
			"color": Color("ffe5ad").lerp(Color("a8ebcd"), rng.randf_range(0.30, 0.90))
		})
	_firefly_draw.multimesh.visible_instance_count = FIREFLY_COUNT
	_firefly_draw.visible = true
	animate(0.0, 0.0)


## Absolute time keeps drift repeatable. Wishes have their own shared _process,
## so calling animate from main never advances a wish twice in the same frame.
func animate(time: float, delta: float) -> void:
	if _flies.is_empty() or not is_instance_valid(_firefly_draw):
		return
	if not is_finite(time) or not is_finite(delta):
		return
	var mm := _firefly_draw.multimesh
	for i in range(_flies.size()):
		var fly: Dictionary = _flies[i]
		var phase: float = fly.phase
		var drift: float = time * fly.speed + phase
		var up: Vector3 = fly.up
		var right: Vector3 = fly.right
		var forward: Vector3 = fly.forward
		var point := _luma_center + up * (_luma_radius + float(fly.height) + sin(drift * 1.17) * 0.12)
		point += right * sin(drift) * 0.28 + forward * cos(drift * 0.79 + phase) * 0.23
		var breath := 0.5 + 0.5 * sin(time * 0.66 + phase)
		var tint: Color = fly.color
		tint.a = 0.10 + 0.64 * breath * breath * breath
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * float(fly.size)), point))
		mm.set_instance_color(i, tint)


## A soft star rises along the supplied surface normal. At most four wishes
## share one additional draw; repeated requests replace the oldest trail.
func wish(origin: Vector3, up: Vector3) -> void:
	if not origin.is_finite() or not up.is_finite():
		return
	var normal := up.normalized() if up.length_squared() > 0.000001 else Vector3.UP
	var frame := _surface_frame(normal)
	if not is_instance_valid(_wish_draw):
		_wish_draw = _make_motes("WishTrails", MAX_WISHES * TRAIL_POINTS)
	if _wishes.size() >= MAX_WISHES:
		_wishes.pop_front()
	_wishes.append({"origin": origin, "up": normal, "right": frame.x, "forward": frame.z, "age": 0.0})
	_wish_draw.visible = true
	_draw_wishes()
	set_process(true)


func _process(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	for i in range(_wishes.size() - 1, -1, -1):
		_wishes[i].age = float(_wishes[i].age) + delta
		if float(_wishes[i].age) >= WISH_DURATION + TRAIL_DELAY * float(TRAIL_POINTS - 1):
			_wishes.remove_at(i)
	_draw_wishes()
	if _wishes.is_empty():
		set_process(false)


func _draw_wishes() -> void:
	if not is_instance_valid(_wish_draw):
		return
	var mm := _wish_draw.multimesh
	var count := 0
	for trail in _wishes:
		var origin: Vector3 = trail.origin
		var up: Vector3 = trail.up
		var right: Vector3 = trail.right
		var forward: Vector3 = trail.forward
		for j in range(TRAIL_POINTS):
			var age := float(trail.age) - float(j) * TRAIL_DELAY
			if age <= 0.0 or age >= WISH_DURATION:
				continue
			var progress := age / WISH_DURATION
			var tail := 1.0 - float(j) / float(TRAIL_POINTS)
			var fade := smoothstep(0.0, 0.16, age) * (1.0 - smoothstep(0.56, 1.0, progress))
			var point := origin + up * (0.15 + age * 1.55)
			point += right * sin(age * 2.1) * 0.13 + forward * (cos(age * 1.6) - 1.0) * 0.09
			var size := (0.36 if j == 0 else lerpf(0.10, 0.23, tail)) * (1.0 - progress * 0.20)
			var tint := Color("c0e9df").lerp(Color("fff0c2"), tail)
			tint.a = fade * tail * tail * (0.88 if j == 0 else 0.36)
			mm.set_instance_transform(count, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), point))
			mm.set_instance_color(count, tint)
			mm.set_instance_custom_data(count, Color(1.0 if j == 0 else 0.0, 0.0, 0.0, 0.0))
			count += 1
	mm.visible_instance_count = count
	_wish_draw.visible = count > 0


func _make_motes(label: String, count: int) -> MultiMeshInstance3D:
	if _mote_material == null:
		var shader := Shader.new()
		shader.code = MOTE_SHADER
		_mote_material = ShaderMaterial.new()
		_mote_material.shader = shader
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _mote_material
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = count
	mm.visible_instance_count = 0
	for i in range(count):
		mm.set_instance_color(i, Color(1.0, 1.0, 1.0, 0.0))
		mm.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, 0.0))
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = mm
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 0.5
	instance.visible = false
	add_child(instance)
	return instance


static func _surface_frame(up: Vector3) -> Basis:
	var reference := Vector3.BACK if absf(up.z) < 0.9 else Vector3.RIGHT
	var right := up.cross(reference).normalized()
	return Basis(right, up, right.cross(up).normalized())
