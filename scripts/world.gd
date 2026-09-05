class_name TinyWorld
extends Node3D
## Surface directions, not positions. Multiply by the walking radius in main.
const Art = preload("res://scripts/art.gd")
const Botany = preload("res://scripts/botany.gd")
const Homes = preload("res://scripts/homes.gd")

var anchors: Dictionary = {}
## World-unit footprint radii; main adds the player's clearance when resolving motion.
var obstacles: Array = []
var _radius: float = 8.0
var _style: int = 0
var _rng := RandomNumberGenerator.new()
var _root: Node3D
var _static_art: Array[Node3D] = []
var _batches: Dictionary = {}
var _palette: Array[Color] = []
var _routes: Array[Dictionary] = []
var _areas: Array[Dictionary] = []
var _terrain_batches: Dictionary = {}
var _terrain_materials: Dictionary = {}
var _paving: ShaderMaterial
var _water: ShaderMaterial
var _grass: ShaderMaterial
var _ground_regions := PackedVector4Array()


func setup(index: int, radius: float) -> void:
	if is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "PlanetLandscape"
	add_child(_root)
	_radius = maxf(radius, 0.1)
	_style = clampi(index, 0, 5)
	_rng.seed = 7031 + _style * 971
	_batches.clear()
	_static_art.clear()
	anchors.clear()
	obstacles.clear()
	_routes.clear()
	_areas.clear()
	_terrain_batches.clear()
	_terrain_materials.clear()
	_ground_regions.clear()
	anchors["spawn"] = Vector3(0, 1, 0.35).normalized()
	anchors["rocket"] = Vector3(-0.35, 1, 0.15).normalized()
	anchors["neighbor"] = Vector3(0.25, 1, 0).normalized()
	anchors["home"] = Vector3(0.22, 1, -0.40).normalized()
	# Ground, path, water, foliage, flowers, architectural accent.
	match _style:
		0: _palette = [Color("85b96b"), Color("f4d7ad"), Color("68bfcc"), Color("469779"), Color("ffd0b6"), Color("ecac89")]
		1: _palette = [Color("a58bc6"), Color("d5b9db"), Color("52bde1"), Color("685899"), Color("f5afdd"), Color("8ce0e2")]
		2: _palette = [Color("a1cdb1"), Color("e1d1ae"), Color("73c6bf"), Color("548e81"), Color("efbe83"), Color("bc805e")]
		3: _palette = [Color("79b6a3"), Color("efd9b5"), Color("6fbfca"), Color("438d83"), Color("ffd39b"), Color("e69c78")]
		4: _palette = [Color("a4bbc9"), Color("e3d9cf"), Color("74aedd"), Color("718dab"), Color("d8d0f5"), Color("89bad2")]
		5: _palette = [Color("d8af78"), Color("f5dfaf"), Color("90bdac"), Color("9aa36b"), Color("fff0b1"), Color("d38b64")]
	_paving = _paving_material()
	_water = _water_material()
	_make_ground()
	if _style == 3:
		anchors.erase("home")
		anchors["town_hall"] = Vector3(0, 1, -0.53).normalized()
		anchors["shop"] = Vector3(-0.55, 1, -0.20).normalized()
		anchors["clothes"] = Vector3(0.55, 1, -0.20).normalized()
		anchors["event"] = Vector3(0.05, 1, 0.08).normalized()
	_make_water()
	_make_paths()
	_make_settlement()
	_make_authored_gardens()
	_scatter_garden()
	_sync_ground_regions()
	_flush_terrain()
	_flush_batches()
	_merge_static_art()


func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	mat.metallic = metallic
	return mat


func set_landscape_detail(active: bool) -> void:
	# Remote moons keep their ground and water silhouette. Buildings, plants and
	# tiny shadows become useful only on the current world or flight destination.
	for child in _root.get_children():
		if child is GeometryInstance3D and child.name != "WalkableSphere":
			var terrain := str(child.name).begins_with("Terrain")
			child.visible = active or terrain


func _make_ground() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = _radius
	mesh.height = _radius * 2.0
	mesh.radial_segments = 96
	mesh.rings = 48
	_grass = _grass_material()
	mesh.material = _grass
	var body := MeshInstance3D.new()
	body.name = "WalkableSphere"
	body.mesh = mesh
	_root.add_child(body)


func _grass_material() -> ShaderMaterial:
	var shader := Shader.new()
	# Object-space 3D noise has no longitude seam or polar UV stretching.
	# Only albedo changes: the walking sphere remains exactly the supplied radius.
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 ground_color : source_color;
uniform bool clover_craft = false;
uniform vec4 soil_color : source_color;
uniform vec4 ground_regions[32];
uniform int ground_region_count = 0;
uniform vec3 foreground_bed_center;
uniform vec3 foreground_bed_right;
uniform vec3 foreground_bed_forward;
uniform vec2 foreground_bed_extent;
uniform vec4 bed_grass_color : source_color;
varying vec3 ground_position;
float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float grass_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(cell), hash3(cell + vec3(1,0,0)), f.x),
		mix(hash3(cell + vec3(0,1,0)), hash3(cell + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(cell + vec3(0,0,1)), hash3(cell + vec3(1,0,1)), f.x),
		mix(hash3(cell + vec3(0,1,1)), hash3(cell + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { ground_position = VERTEX; }
void fragment() {
	float patches = grass_noise(ground_position * 1.15);
	float grain = grass_noise(ground_position * 23.0);
	float fade = 1.0 - smoothstep(0.025, 0.12, length(fwidth(ground_position)));
	float shade = 0.96 + 0.08 * patches + (grain - 0.5) * 0.025 * fade;
	ALBEDO = ground_color.rgb * shade;
	if (clover_craft) {
		float broad = grass_noise(ground_position * 0.38 + vec3(4.2,1.7,6.3));
		vec3 grass = ground_color.rgb * mix(vec3(0.94,1.0,0.94), vec3(1.045,1.005,0.94), broad);
		grass *= 0.94 + 0.11 * patches + (grain - 0.5) * 0.014 * fade;
		float soil = 0.0;
		float verge = 0.0;
		float edge = (grass_noise(ground_position * 2.4) - 0.5) * 0.24;
		for (int i = 0; i < 32; i++) {
			if (i >= ground_region_count) { break; }
			vec4 region = ground_regions[i];
			float d = distance(ground_position, region.xyz) / abs(region.w) + edge;
			float strength = region.w > 0.0 ? 0.72 : 0.22;
			soil = max(soil, (1.0 - smoothstep(0.25,1.08,d)) * strength);
			verge = max(verge, 1.0 - smoothstep(0.75,1.9,d));
		}
		grass *= mix(vec3(1.0), vec3(0.96,0.985,0.95), verge);
		// One existing foreground bed has a readable, softly asymmetric soil margin.
		vec3 offset = ground_position - foreground_bed_center;
		vec2 bed = vec2(dot(offset,foreground_bed_right), dot(offset,foreground_bed_forward));
		float angle = atan(bed.y,bed.x);
		float outline = 1.0 + 0.065*sin(angle*3.0+0.7) + 0.035*cos(angle*2.0-1.2);
		float bed_distance = length(bed/foreground_bed_extent)/outline;
		// The facing test confines this tangent-plane mask to the nearby hemisphere.
		float local = step(0.0,dot(ground_position,foreground_bed_center));
		float bed_soil = (1.0-smoothstep(0.88,1.02,bed_distance))*local;
		float bed_verge = (1.0-smoothstep(1.0,1.34,bed_distance))*local;
		grass = mix(grass,bed_grass_color.rgb*(0.95+patches*0.08),bed_verge*0.58);
		soil = max(soil,bed_soil*0.90);
		ALBEDO = mix(grass, soil_color.rgb * (0.93 + 0.12 * patches), soil);
	}
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("ground_color", _palette[0])
	material.set_shader_parameter("clover_craft", _style == 0)
	material.set_shader_parameter("soil_color", Color("897958"))
	return material


func _planting_ground(direction: Vector3, extent: Vector2, color: Color) -> void:
	if _style == 0:
		var p := direction.normalized() * _radius
		_ground_regions.append(Vector4(p.x, p.y, p.z, maxf(extent.x, extent.y)))
	else:
		_patch(direction, _outline(direction, extent, true), color, 0.002)


func _sync_ground_regions() -> void:
	if _style != 0:
		return
	# Soft wear at the existing threshold; the accepted paving stays on top untouched.
	for side in [-1.0, 1.0]:
		var p := _offset(anchors["home"], side * 1.25, 2.05) * _radius
		_ground_regions.append(Vector4(p.x, p.y, p.z, -0.72))
	var count := mini(_ground_regions.size(), 32)
	var uniforms := _ground_regions.duplicate()
	uniforms.resize(32)
	_grass.set_shader_parameter("ground_regions", uniforms)
	_grass.set_shader_parameter("ground_region_count", count)
	# Same right-hand shrub as the authored garden; extend soil, not its collider.
	var bed := Vector3(0.64,1,0.57).normalized()
	var frame := _frame(bed)
	_grass.set_shader_parameter("foreground_bed_center", _offset(bed,-0.04,0.08)*_radius)
	_grass.set_shader_parameter("foreground_bed_right", frame.x)
	_grass.set_shader_parameter("foreground_bed_forward", frame.z)
	_grass.set_shader_parameter("foreground_bed_extent", Vector2(0.86,0.68))
	_grass.set_shader_parameter("bed_grass_color", Color("739c65"))


func _frame(direction: Vector3) -> Basis:
	var up := direction.normalized()
	var reference := Vector3.BACK
	if absf(up.dot(reference)) > 0.96:
		reference = Vector3.RIGHT
	var right := up.cross(reference).normalized()
	return Basis(right, up, right.cross(up).normalized())


func _place(node: Node3D, direction: Vector3, size: float, yaw: float = 0.0) -> void:
	_root.add_child(node)
	var lift := 0.0
	for area in _areas:
		if str(area.reason).contains("path") and _area_intersects(direction, 0.0, area):
			lift = _radius * 0.006
			break
	node.transform = Transform3D(_frame(direction).rotated(direction.normalized(), yaw).scaled_local(Vector3.ONE * size), direction.normalized() * (_radius + lift))
	_static_art.append(node)


func _material_key(material: StandardMaterial3D) -> String:
	# Include all stored rendering settings, not just color. This preserves emission,
	# roughness, metallic, transparency, texture references, shading and culling.
	var values: Array = []
	for property in material.get_property_list():
		var key := String(property.name)
		if (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0 or key.begins_with("resource_") or key == "script":
			continue
		values.append([key, material.get(key)])
	return var_to_str(values)


func _collect_static_surfaces(node: Node3D, transform_to_root: Transform3D, collected: Array) -> bool:
	if node is MeshInstance3D:
		if node.mesh == null or node.skin != null:
			return false
		if node.mesh is ArrayMesh and node.mesh.get_blend_shape_count() > 0:
			return false
		if not node.visible or node.material_overlay != null:
			return false
		for surface in range(node.mesh.get_surface_count()):
			var material: Material = node.get_active_material(surface)
			if not material is StandardMaterial3D:
				return false
			if node.mesh is ArrayMesh and node.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				return false
			collected.append({"mesh": node.mesh, "surface": surface, "transform": transform_to_root,
				"material": material, "shadow": node.cast_shadow})
	elif node.get_class() != "Node3D":
		return false
	for child in node.get_children():
		if not child is Node3D or not _collect_static_surfaces(child, transform_to_root * child.transform, collected):
			return false
	return true


func _merge_static_art() -> void:
	# Only roots registered by _place participate. Terrain shaders, path ArrayMeshes,
	# garden MultiMeshes and main's dynamic siblings are never traversed.
	var groups: Dictionary = {}
	var originals: Array[Node3D] = []
	for art_root in _static_art:
		var surfaces: Array = []
		if not _collect_static_surfaces(art_root, art_root.transform, surfaces):
			continue
		originals.append(art_root)
		for surface in surfaces:
			var key := _material_key(surface.material) + ":shadow=" + str(surface.shadow)
			if not groups.has(key):
				groups[key] = []
			groups[key].append(surface)
	var merged_nodes: Array[MeshInstance3D] = []
	for key in groups:
		var surfaces: Array = groups[key]
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		builder.set_material(surfaces[0].material)
		for surface in surfaces:
			builder.append_from(surface.mesh, surface.surface, surface.transform)
		var mesh := builder.commit()
		if mesh == null:
			for pending in merged_nodes:
				pending.free()
			return
		var instance := MeshInstance3D.new()
		instance.name = "StaticArtMaterial_" + str(merged_nodes.size())
		instance.mesh = mesh
		instance.cast_shadow = surfaces[0].shadow
		merged_nodes.append(instance)
	for instance in merged_nodes:
		_root.add_child(instance)
	# All source geometry stays alive until every material batch was constructed.
	for original in originals:
		_root.remove_child(original)
		original.free()
	_static_art.clear()


func _disc(direction: Vector3, angular_radius: float, color: Color, lift: float = 0.003, material: Material = null) -> void:
	var frame := _frame(direction)
	var center := direction.normalized()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	# Concentric strips follow the sphere instead of cutting a flat fan into it.
	for ring in range(6):
		var inner := angular_radius * float(ring) / 6.0
		var outer := angular_radius * float(ring + 1) / 6.0
		for i in range(40):
			var a := TAU * float(i) / 40.0
			var b := TAU * float(i + 1) / 40.0
			var ta := frame.x * cos(a) + frame.z * sin(a)
			var tb := frame.x * cos(b) + frame.z * sin(b)
			var p := (center + ta * inner).normalized()
			var q := (center + ta * outer).normalized()
			var r := (center + tb * outer).normalized()
			var t := (center + tb * inner).normalized()
			for normal in [p, q, r, p, r, t]:
				vertices.append(normal * _radius * (1.0 + lift))
				normals.append(normal)
	_surface(vertices, normals, color, material)


func _surface(vertices: PackedVector3Array, normals: PackedVector3Array, color: Color, material: Material = null, uvs: PackedVector2Array = PackedVector2Array()) -> void:
	if material == null:
		var color_key := color.to_html()
		if not _terrain_materials.has(color_key):
			var mat := _material(color)
			mat.cull_mode = BaseMaterial3D.CULL_BACK
			_terrain_materials[color_key] = mat
		material = _terrain_materials[color_key]
	var key := material.get_instance_id()
	if not _terrain_batches.has(key):
		_terrain_batches[key] = {"material": material, "vertices": PackedVector3Array(), "normals": PackedVector3Array(), "uvs": PackedVector2Array()}
	_terrain_batches[key].vertices.append_array(vertices)
	_terrain_batches[key].normals.append_array(normals)
	if uvs.is_empty():
		uvs.resize(vertices.size())
	_terrain_batches[key].uvs.append_array(uvs)


func _flush_terrain() -> void:
	# Shared paving, water, soil and bank materials each become one surface draw.
	for batch in _terrain_batches.values():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = batch.vertices
		arrays[Mesh.ARRAY_NORMAL] = batch.normals
		arrays[Mesh.ARRAY_TEX_UV] = batch.uvs
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, batch.material)
		var instance := MeshInstance3D.new()
		instance.name = "TerrainSurface"
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(instance)
	_terrain_batches.clear()


func _ribbon(points: Array[Vector3], width: float, color: Color, lift: float, material: Material = null, widths: PackedFloat32Array = PackedFloat32Array()) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var edges: Array[Vector3] = []
	for i in range(points.size()):
		var n := points[i].normalized()
		var tangent := _ribbon_tangent(points, i)
		var side := n.cross(tangent).normalized() * (widths[i] if widths.size() == points.size() else width)
		edges.append((n - side).normalized())
		edges.append((n + side).normalized())
	for i in range(points.size() - 1):
		var j := i * 2
		# Godot fronts are clockwise: cross(edge1, edge2).dot(outward) < 0.
		# This matches _disc; two-sided materials previously hid the reversal.
		for k in [j, j + 1, j + 2, j + 1, j + 3, j + 2]:
			vertices.append(edges[k] * _radius * (1.0 + lift))
			normals.append(edges[k])
			# Lateral coordinate follows the existing silhouette, including bends.
			uvs.append(Vector2(0.0 if k % 2 == 0 else 1.0, 0.0))
	_surface(vertices, normals, color, material, uvs)


func _ribbon_tangent(points: Array[Vector3], index: int) -> Vector3:
	if points[0].is_equal_approx(points[-1]) and (index == 0 or index == points.size() - 1):
		return points[1] - points[-2]
	return points[mini(index + 1, points.size() - 1)] - points[maxi(0, index - 1)]


func _river_direction(t: float) -> Vector3:
	return Vector3(0.57 + 0.12 * sin(t * 7.0), cos(t), sin(t)).normalized()


func _make_water() -> void:
	if _style == 1:
		var points: Array[Vector3] = []
		var widths := PackedFloat32Array()
		for i in range(193):
			var t := -PI + TAU * float(i) / 192.0
			points.append(_river_direction(t))
			widths.append(0.052 * (1.0 + 0.16 * sin(t * 5.0) + 0.07 * cos(t * 11.0)))
		_ribbon(points, 0.052, _palette[2], 0.006, _water, widths)
		for side in [-1.0, 1.0]:
			var edge: Array[Vector3] = []
			var rim: Array[Vector3] = []
			var outer: Array[Vector3] = []
			for i in range(points.size()):
				var across: Vector3 = points[i].cross(_ribbon_tangent(points, i)).normalized() * side
				edge.append((points[i] + across * widths[i]).normalized())
				rim.append((points[i] + across * (widths[i] + 0.008)).normalized())
				outer.append((points[i] + across * (widths[i] + 0.030)).normalized())
			_shore_strip(edge, rim, 0.045, 0.13, _palette[1].darkened(0.38))
			_shore_strip(rim, outer, 0.13, 0.014, _palette[1].darkened(0.15))
			# The same segment envelope protects water and banks from placement.
			if side < 0.0:
				for i in range(points.size() - 1):
					_routes.append({"start": points[i], "end": points[i + 1], "width": _radius * atan(maxf(widths[i], widths[i + 1]) + 0.030), "reason": "Keep the riverbank clear."})
	else:
		for pond in [{"n": Vector3(-0.65, 0.78, -0.35).normalized(), "angle": 0.20}, {"n": Vector3(0.3, -0.7, 0.6).normalized(), "angle": 0.24}]:
			var center: Vector3 = pond.n
			var extent := Vector2.ONE * _radius * tan(float(pond.angle))
			var edge := _outline(center, extent, true)
			var rim := _outline(center, extent + Vector2.ONE * 0.075, true)
			var outer := _outline(center, extent + Vector2.ONE * 0.28, true)
			_patch(center, edge, _palette[2], 0.006, _water)
			_shore_strip(edge, rim, 0.045, 0.14, _palette[1].darkened(0.38), true)
			_shore_strip(rim, outer, 0.14, 0.014, _palette[1].darkened(0.15), true)
			_register_area(center, outer, "Keep decorations out of the pond.")
			for i in [3, 5, 19, 20, 21, 37, 49]:
				_stamp("stone", outer[i], Vector3(0.019, 0.012, 0.015), 0.009, 1)
				if i % 2 == 1:
					_stamp("leaf", outer[(i + 2) % outer.size()], Vector3(0.022, 0.023, 0.016), 0.016, 3)


func _make_paths() -> void:
	var hub := Vector3.UP
	_paved_area(hub, Vector2(3.4, 3.4) if _style == 3 else Vector2(0.82, 0.82))
	for key in anchors:
		var destination: Vector3 = anchors[key]
		_route(hub, destination, 0.66 if _style == 3 else 0.52)


func _route(start: Vector3, end: Vector3, half_width: float) -> void:
	var points: Array[Vector3] = []
	for i in range(33):
		points.append(start.slerp(end, float(i) / 32.0).normalized())
	_ribbon(points, tan(half_width / _radius), _palette[1], 0.006, _paving)
	_disc(end, tan(half_width / _radius), _palette[1], 0.006, _paving)
	_routes.append({"start": start, "end": end, "width": half_width, "reason": "Leave the path clear for wandering."})


func _paving_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_back;
uniform vec4 paving_color : source_color;
varying vec3 paving_position;
float pavers(vec2 p) {
	p *= 2.8;
	p.x += mod(floor(p.y), 2.0) * 0.5;
	vec2 edge = min(fract(p), 1.0 - fract(p));
	vec2 seam = smoothstep(vec2(0.006), fwidth(p) * 0.65 + 0.025, edge);
	float stone = fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453);
	return mix(0.89, 0.97 + stone * 0.045, seam.x * seam.y);
}
void vertex() { paving_position = VERTEX; }
void fragment() {
	vec3 weight = pow(abs(normalize(paving_position)), vec3(6.0));
	weight /= max(dot(weight, vec3(1.0)), 0.001);
	float shade = dot(weight, vec3(pavers(paving_position.yz), pavers(paving_position.xz), pavers(paving_position.xy)));
	ALBEDO = paving_color.rgb * shade;
	ROUGHNESS = 0.91;
	SPECULAR = 0.16;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("paving_color", _palette[1])
	return material


func _water_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_back;
uniform vec4 water_color : source_color;
uniform bool river_water = false;
uniform vec4 deep_water : source_color = vec4(0.239, 0.545, 0.616, 1.0);
uniform vec4 shallow_water : source_color = vec4(0.510, 0.761, 0.729, 1.0);
uniform vec4 reflected_sky : source_color = vec4(0.616, 0.667, 0.765, 1.0);
varying vec3 water_position;
void vertex() { water_position = VERTEX; }
void fragment() {
	float a = dot(water_position, vec3(1.7, 0.8, 1.1)) - TIME * 0.36;
	float b = dot(water_position, vec3(-0.6, 1.4, 2.1)) + TIME * 0.23;
	float swell = sin(a) * sin(b);
	vec3 outward = normalize(water_position);
	vec3 slope = vec3(cos(a) * sin(b), sin(a + b), sin(a) * cos(b));
	slope -= outward * dot(slope, outward);
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(outward + slope * 0.022, 0.0)).xyz);
	float rim = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 3.0);
	float ripple = smoothstep(0.89, 0.99, sin(a * 3.0 + sin(b))) * smoothstep(0.1, 0.8, cos(b * 1.7));
	vec3 body = water_color.rgb * (0.78 + swell * 0.045);
	if (river_water) {
		// Smooth shallows across the original ribbon; no extra overlay strips.
		float across = abs(UV.x * 2.0 - 1.0);
		float shore = smoothstep(0.30, 0.98, across);
		float reflected = 0.5 + 0.27 * sin(dot(water_position, vec3(0.47, 0.22, 0.63)) + TIME * 0.07)
			+ 0.23 * cos(dot(water_position, vec3(-0.31, 0.57, 0.28)) - TIME * 0.05);
		body = mix(deep_water.rgb, shallow_water.rgb, shore * 0.64);
		body = mix(body, reflected_sky.rgb, smoothstep(0.15, 0.9, reflected) * 0.17);
		body *= 0.96 + swell * 0.035;
	}
	ALBEDO = body + vec3(0.055, 0.075, 0.08) * (rim + ripple * 0.45);
	ROUGHNESS = 0.32;
	SPECULAR = 0.52;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("water_color", _palette[2])
	material.set_shader_parameter("river_water", _style == 1)
	return material


func _outline(center: Vector3, extent: Vector2, irregular: bool = false) -> Array[Vector3]:
	var frame := _frame(center)
	var result: Array[Vector3] = []
	for i in range(64):
		var angle := TAU * float(i) / 64.0
		var shape := 1.0 + 0.075 * sin(angle * 3.0 + 0.7) + 0.045 * cos(angle * 5.0) if irregular else 1.0
		result.append((center + (frame.x * cos(angle) * extent.x + frame.z * sin(angle) * extent.y) * shape / _radius).normalized())
	return result


func _patch(center: Vector3, outline: Array[Vector3], color: Color, lift: float, material: Material = null) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for ring in range(8):
		for i in range(outline.size()):
			var j := (i + 1) % outline.size()
			var a := center.slerp(outline[i], float(ring) / 8.0)
			var b := center.slerp(outline[i], float(ring + 1) / 8.0)
			var c := center.slerp(outline[j], float(ring + 1) / 8.0)
			var d := center.slerp(outline[j], float(ring) / 8.0)
			var face := PackedVector3Array([a, b, c])
			if ring > 0:
				face.append_array(PackedVector3Array([a, c, d]))
			for n in face:
				vertices.append(n * _radius * (1.0 + lift))
				normals.append(n)
	_surface(vertices, normals, color, material)


func _shore_strip(inner: Array[Vector3], outer: Array[Vector3], inner_height: float, outer_height: float, color: Color, closed: bool = false) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(inner.size() if closed else inner.size() - 1):
		var j := (i + 1) % inner.size()
		var a := inner[i] * (_radius + inner_height)
		var b := outer[i] * (_radius + outer_height)
		var c := outer[j] * (_radius + outer_height)
		var d := inner[j] * (_radius + inner_height)
		for face in [[a, b, c], [a, c, d]]:
			var normal: Vector3 = (face[1] - face[0]).cross(face[2] - face[0]).normalized()
			if normal.dot(a + b + c + d) > 0.0:
				face.reverse()
			else:
				normal = -normal
			for point in face:
				vertices.append(point)
				normals.append(normal)
	_surface(vertices, normals, color)


func _paved_area(center: Vector3, extent: Vector2) -> void:
	var outline := _outline(center, extent)
	_patch(center, outline, _palette[1], 0.006, _paving)
	_register_area(center, outline, "Leave the path and patio clear for wandering.")


func _register_area(center: Vector3, outline: Array[Vector3], reason: String) -> void:
	var frame := _frame(center)
	var polygon := PackedVector2Array()
	var bound := 0.0
	for n in outline:
		polygon.append(Vector2(n.dot(frame.x), n.dot(frame.z)) / n.dot(center))
		bound = maxf(bound, n.angle_to(center) * _radius)
	_areas.append({"normal": center, "outline": outline, "polygon": polygon, "frame": frame, "bound": bound, "reason": reason})


func _area_intersects(direction: Vector3, padding: float, area: Dictionary) -> bool:
	var center: Vector3 = area.normal
	if direction.angle_to(center) * _radius > float(area.bound) + padding:
		return false
	var frame: Basis = area.frame
	if direction.dot(center) > 0.0:
		var p := Vector2(direction.dot(frame.x), direction.dot(frame.z)) / direction.dot(center)
		if Geometry2D.is_point_in_polygon(p, area.polygon):
			return true
	var outline: Array[Vector3] = area.outline
	for i in range(outline.size()):
		if _arc_distance(direction, outline[i], outline[(i + 1) % outline.size()]) <= padding:
			return true
	return false


## PlanetArt's stable integer factory API.
func _art_piece(kind: String, variant: String) -> Node3D:
	match kind:
		"tree":
			return Art.tree(_style)
		"building":
			var building: Node3D = Homes.make(_style) if variant == "home" else Art.building({"town_hall": 1, "shop": 2, "clothes": 3}.get(variant, 0))
			if variant == "home" and _style in [1, 2]:
				_home_identity(building)
			return building
		"decoration":
			return Art.decoration({"fountain": 1, "gear": 4, "flower": 5}.get(variant, 5))
	return null


func _home_identity(building: Node3D) -> void:
	# Local material overrides preserve the shared art factory and all glass.
	var roof_color := Color("b5a0d1") if _style == 1 else Color("c88d68")
	var frame_color := Color("c4afdb") if _style == 1 else Color("789bb7")
	for label in ["RoofCap", "DoorFrame"]:
		var part := building.get_node_or_null(label) as MeshInstance3D
		if part != null:
			part.material_override = _material(roof_color if label == "RoofCap" else frame_color)
	if _style == 1:
		var metal := _material(Color("d4c596"), 0.25)
		Art._rod(building, "LumiRoofAerial", Vector3(0.34,1.36,-0.08), Vector3(0.34,1.88,-0.08), 0.018, metal)
		Art._ball(building, "LumiAerialPearl", Vector3(0.34,1.91,-0.08), Vector3.ONE * 0.13, _material(Color("9bdccd")))
	else:
		var copper := _material(Color("a5684e"), 0.3)
		var center := Vector3(0.36,1.43,0.48)
		Art._ring(building, "BoltWorkshopGear", center, 0.145, 0.037, copper, true)
		for i in range(8):
			var angle := TAU * float(i) / 8.0
			var tooth := BoxMesh.new()
			tooth.size = Vector3(0.065,0.083,0.055)
			var node := Art._mesh(building, "GearTooth", tooth, center + Vector3(sin(angle),cos(angle),0) * 0.18, copper)
			node.rotation.z = -angle


func _make_settlement() -> void:
	var locations := ["home"]
	if _style == 3:
		locations = ["town_hall", "shop", "clothes"]
	for key in locations:
		var direction: Vector3 = anchors[key]
		var building := _art_piece("building", key)
		if building != null:
			var footprint := _footprint(building)
			# Door height increases with the building, but the full visible footprint
			# is capped at 1.7: collider + player 0.22 still leaves 0.88 inside E=2.8.
			var size := minf(1.65, 1.70 / maxf(footprint, 0.01))
			_place(building, direction, size)
			_add_obstacle(direction, maxf(footprint * size, 0.1))
			var threshold := (direction + _frame(direction).z * (1.7 / _radius)).normalized()
			_paved_area(threshold, Vector2(1.15, 0.95))
		else:
			_fallback_building(direction, key == "town_hall")
			_add_obstacle(direction, _radius * (0.072 if key == "town_hall" else 0.058))
	if _style == 3:
		var event_direction: Vector3 = anchors["event"]
		_disc(event_direction, 0.055, _palette[5], 0.008)
		var decoration := _art_piece("decoration", "fountain")
		if decoration != null:
			_place(decoration, event_direction, _radius * 0.07)
			_add_obstacle(event_direction, minf(_footprint(decoration) * _radius * 0.07, 0.8))
		else:
			_stamp("stone", event_direction, Vector3(0.045, 0.012, 0.045), 0.012, 5)
			_stamp("stone", event_direction, Vector3(0.027, 0.008, 0.027), 0.023, 2)
			_stamp("stone", event_direction, Vector3(0.008, 0.028, 0.008), 0.030, 5)
			_add_obstacle(event_direction, _radius * 0.045)


func _add_obstacle(direction: Vector3, footprint: float) -> void:
	obstacles.append({"normal": direction.normalized(), "radius": footprint})


func _footprint(node: Node3D, accumulated: Transform3D = Transform3D.IDENTITY) -> float:
	# Bound horizontal mesh extents in the art root's coordinates, including children.
	var extent := 0.0
	if node is MeshInstance3D and node.mesh != null:
		var bounds: AABB = node.get_aabb()
		for i in range(8):
			var point: Vector3 = accumulated * bounds.get_endpoint(i)
			extent = maxf(extent, Vector2(point.x, point.z).length())
	for child in node.get_children():
		if child is Node3D:
			extent = maxf(extent, _footprint(child, accumulated * child.transform))
	return extent


func _fallback_building(direction: Vector3, civic: bool) -> void:
	var size := 1.25 if civic else 1.0
	_stamp("box", direction, Vector3(0.085, 0.065, 0.075) * size, 0.035 * size, 4)
	_stamp("roof", direction, Vector3(0.075, 0.040, 0.075) * size, 0.085 * size, 5)
	var frame := _frame(direction)
	var door := (direction + frame.z * 0.039 * size).normalized()
	_stamp("box", door, Vector3(0.022, 0.036, 0.006) * size, 0.019 * size, 3)
	for side in [-1.0, 1.0]:
		var window: Vector3 = (direction + frame.z * 0.040 * size + frame.x * side * 0.026 * size).normalized()
		_stamp("box", window, Vector3(0.013, 0.015, 0.007) * size, 0.041 * size, 2)


## Terrain-only placement test. Main separately checks anchors and solid obstacles.
## Footprint is in world units. This does not use the broader scenery reservations.
func placement_issue(direction: Vector3, footprint: float) -> String:
	if not direction.is_finite() or direction.length_squared() < 0.000001:
		return "Choose a spot on the planet."
	var n := direction.normalized()
	var padding := maxf(footprint, 0.0)
	# These records are created with the actual geometry, including patio and
	# irregular bank outlines. Paths remain on the original hub-to-anchor arcs.
	for area in _areas:
		if _area_intersects(n, padding, area):
			return area.reason
	for route in _routes:
		if _arc_distance(n, route.start, route.end) <= float(route.width) + padding:
			return route.reason
	return ""


func _path_distance(direction: Vector3, destination: Vector3) -> float:
	return _arc_distance(direction, Vector3.UP, destination)


func _arc_distance(direction: Vector3, start: Vector3, destination: Vector3) -> float:
	# Exact nearest point on a finite great-circle arc, in world units.
	var origin := start.normalized()
	var end := destination.normalized()
	var arc := origin.angle_to(end)
	var distance := minf(direction.angle_to(origin), direction.angle_to(end))
	var tangent := end - origin * end.dot(origin)
	if tangent.length_squared() > 0.000001:
		tangent = tangent.normalized()
		var along := atan2(direction.dot(tangent), direction.dot(origin))
		if along >= 0.0 and along <= arc:
			var closest := origin * cos(along) + tangent * sin(along)
			distance = minf(distance, direction.angle_to(closest))
	return distance * _radius


func _reserved(direction: Vector3) -> bool:
	for value in anchors.values():
		if direction.distance_to(value) * _radius < 1.8:
			return true
	if not placement_issue(direction, 0.45).is_empty():
		return true
	for obstacle in obstacles:
		if direction.distance_to(obstacle.normal) * _radius < float(obstacle.radius) + 0.75:
			return true
	if direction.y > 0.94:
		return true
	return false


func _solid_clear(direction: Vector3, footprint: float) -> bool:
	for area in _areas:
		if str(area.reason).contains("pond") and _area_intersects(direction, footprint, area):
			return false
	for route in _routes:
		if _arc_distance(direction, route.start, route.end) < float(route.width) + footprint + 0.12:
			return false
	for key in ["spawn", "rocket", "neighbor"]:
		if direction.distance_to(anchors[key]) * _radius < footprint + 1.0:
			return false
	for obstacle in obstacles:
		if direction.distance_to(obstacle.normal) * _radius < footprint + float(obstacle.radius) + 0.4:
			return false
	# Keep the two quest pickup clearings open as well.
	var pickup := Vector3(0.38, 1, 0.40) if _style == 0 else Vector3(-0.12, 1, 0.46)
	if _style in [0, 3] and direction.distance_to(pickup.normalized()) * _radius < footprint + 0.7:
		return false
	return true


func _garden_tree(direction: Vector3, size: float) -> void:
	var trunk := 0.18 * size
	if not _solid_clear(direction, trunk):
		return
	var tree := Botany.tree() if _style == 0 else Art.tree(_style if _style < 4 else (3 if _style == 4 else 2))
	if _style >= 4:
		_tint_tree(tree)
	_place(tree, direction, size, _rng.randf_range(-0.4, 0.4))
	_add_obstacle(direction, trunk)
	_planting_ground(direction, Vector2.ONE * size * 0.40, _palette[3].darkened(0.34))


func _starter_prop(kind: int, direction: Vector3, size: float, yaw: float = 0.0) -> void:
	var prop := Art.decoration(kind)
	var footprint := _footprint(prop) * size
	if not _solid_clear(direction, footprint):
		prop.free()
		return
	_place(prop, direction, size, yaw)
	_add_obstacle(direction, footprint)


func _flower_bed(direction: Vector3, spread: float, count: int) -> void:
	for route in _routes:
		if _arc_distance(direction, route.start, route.end) < float(route.width) + spread * _radius:
			return
	for area in _areas:
		if str(area.reason).contains("pond") and _area_intersects(direction, spread * _radius, area):
			return
	var frame := _frame(direction)
	_planting_ground(direction, Vector2(spread, spread * 0.65) * _radius, _palette[3].darkened(0.40))
	for i in range(count):
		var angle := float(i) * 2.39996323
		var distance := sqrt((float(i) + 0.5) / count) * spread
		var flower := (direction + (frame.x * cos(angle) + frame.z * sin(angle) * 0.60) * distance).normalized()
		var height := _rng.randf_range(0.027, 0.042)
		_stamp("stem", flower, Vector3(0.0025, height, 0.0025), height * 0.5, 3)
		_stamp("stone", flower, Vector3(0.009, 0.005, 0.009), height, 4 if i % 4 != 0 else 5)
		if i % 3 == 0:
			_stamp("leaf", flower, Vector3(0.020, 0.013, 0.015), 0.011, 3)


func _make_authored_gardens() -> void:
	if _style == 0:
		# Home -> open threshold -> side patio. The middle lawn stays open.
		var home: Vector3 = anchors["home"]
		var patio := _offset(home, 3.9, -0.2)
		_paved_area(patio, Vector2(2.45, 2.10))
		_route(_offset(home, 0.0, 2.1), _offset(patio, -1.35, 0.45), 0.48)
		var chair := _offset(patio, 1.45, 0.65)
		var tea := _offset(patio, -0.48, -1.25)
		_starter_prop(6, chair, 1.10, _toward(chair, tea))
		_starter_prop(7, tea, 1.10)
		_starter_prop(10, _offset(home, -3.0, 0.7), 1.15)
		_starter_prop(13, _offset(patio, -0.9, 1.65), 1.15)
		for offset in [Vector2(1.8,-1.8), Vector2(-0.45,-3.7), Vector2(4.1,0.1)]:
			_shrub_cluster(_offset(patio, offset.x, offset.y), 1.15)
		for offset in [Vector2(2.9,-3.3), Vector2(4.1,-1.6)]:
			_garden_tree(_offset(patio, offset.x, offset.y), 1.12)
		for offset in [Vector2(2.3,-2.6), Vector2(-0.8,-2.4), Vector2(3.0,1.0)]:
			_flower_bed(_offset(patio, offset.x, offset.y), 0.065, 15)
		# Frame the ordinary walking view with two planted foreground edges.
		# The right bed sits beyond the quest pickup's reserved approach.
		_garden_tree(Vector3(-0.60, 1, 0.35).normalized(), 1.05)
		_garden_tree(Vector3(0.70, 1, 0.30).normalized(), 1.10)
		_shrub_cluster(Vector3(-0.50, 1, 0.55).normalized(), 1.15)
		_shrub_cluster(Vector3(0.64, 1, 0.57).normalized(), 1.15)
		_flower_bed(Vector3(-0.46, 1, 0.67).normalized(), 0.075, 18)
		_flower_bed(Vector3(0.58, 1, 0.72).normalized(), 0.070, 17)
	elif _style == 1:
		# A waterside sky-watching terrace, entered from the spawn-side path.
		var pause := Vector3(0.12, 1, 0.83).normalized()
		_paved_area(pause, Vector2(1.40, 1.60))
		_route(Vector3.UP, Vector3(0.09, 1, 0.61).normalized(), 0.44)
		var seat := Vector3(-0.08, 1, 0.81).normalized()
		var observatory := Vector3(0.26, 1, 1.07).normalized()
		_starter_prop(9, seat, 1.15, _toward(seat, observatory))
		_starter_prop(14, observatory, 1.05, 0.35)
		_starter_prop(13, Vector3(-0.34, 1, 1.14).normalized(), 1.10)
		for offset in [Vector2(-3.1,-0.4), Vector2(0.2,3.3)]:
			_shrub_cluster(_offset(pause, offset.x, offset.y), 1.10)
		# Distinct upstream and downstream groups; keep Lumi's backdrop open.
		for t in [-0.85, 1.25]:
			var bank := (_river_direction(t) + Vector3(-0.27, 0, 0)).normalized()
			_garden_tree(bank, 1.20)
			_flower_bed((bank - _frame(bank).x * 0.09).normalized(), 0.065, 16)
		# Three low groups on the terrace-facing reach, entirely landward of the rim.
		for t in [0.22, 0.49, 0.69]:
			var center := _river_direction(t)
			var tangent := _river_direction(t + 0.01) - _river_direction(t - 0.01)
			var landward := -center.cross(tangent).normalized()
			var width: float = 0.052 * (1.0 + 0.16 * sin(t * 5.0) + 0.07 * cos(t * 11.0))
			var n := (center + landward * (width + 0.058)).normalized()
			_stamp("stone", n, Vector3(0.023, 0.012, 0.017), 0.010, 1)
			var plant := (n + landward * 0.025 + tangent.normalized() * 0.023).normalized()
			_stamp("leaf", plant, Vector3(0.027, 0.024, 0.020), 0.018, 3)
			_stamp("leaf", (plant + tangent.normalized() * 0.026).normalized(), Vector3(0.019, 0.017, 0.016), 0.012, 3)
	elif _style == 2:
		for point in [Vector3(-0.48,1,-0.75), Vector3(0.57,1,0.38)]:
			_starter_prop(2, point.normalized(), 1.20)
			_flower_bed((point + Vector3(0,0,0.13)).normalized(), 0.06, 14)
		_make_bolt_workbench(_offset(anchors["home"], -3.35, -0.12))
		_shrub_cluster(Vector3(-0.90,1,-1.30).normalized(), 1.15)
	elif _style == 3:
		# Inward-facing seating and a shared picnic at the star's front edge.
		var event: Vector3 = anchors["event"]
		var bench := Vector3(-0.26, 1, 0.32).normalized()
		var picnic := Vector3(0.30, 1, 0.23).normalized()
		_starter_prop(3, bench, 1.20, _toward(bench, event))
		_starter_prop(16, picnic, 1.05, _toward(picnic, event))
		_starter_prop(13, Vector3(-0.46, 1, 0.41).normalized(), 1.15)
		_starter_prop(17, Vector3(0.46, 1, 0.44).normalized(), 1.10)
		for point in [Vector3(-0.27,1,0.54), Vector3(0.20,1,0.57), Vector3(-0.62,1,-0.57), Vector3(0.62,1,-0.57)]:
			_shrub_cluster(point.normalized(), 1.30)
		for point in [Vector3(-0.80,1,-0.38), Vector3(0.80,1,-0.38), Vector3(-0.30,1,-0.85), Vector3(0.30,1,-0.85)]:
			_garden_tree(point.normalized(), _radius * 0.12)
		for point in [Vector3(-0.39,1,0.47), Vector3(0.42,1,0.51)]:
			_flower_bed(point.normalized(), 0.07, 18)
	elif _style == 4:
		# An explorer's weather station and stargazing camp on a cool moon meadow.
		var camp := _offset(anchors["home"], -3.35, -0.1)
		_paved_area(camp, Vector2(1.45, 1.35))
		_route(_offset(anchors["home"], 0, 2.0), _offset(camp, 0.8, 0.7), 0.42)
		_starter_prop(14, _offset(camp, -0.1, -0.42), 1.10, -0.5)
		_starter_prop(9, _offset(camp, 0.5, 1.2), 1.12)
		_starter_prop(4, Vector3(0.65,1,-0.75).normalized(), 1.05)
		_starter_prop(10, _offset(anchors["home"], 2.8, 0.2), 1.05)
		for point in [Vector3(-0.67,1,0.2), Vector3(0.73,1,0.2), Vector3(-0.52,1,-0.9)]:
			_garden_tree(point.normalized(), 1.1)
		for point in [Vector3(-0.55,1,0.52), Vector3(0.55,1,0.72)]:
			_shrub_cluster(point.normalized(), 1.02)
			_flower_bed((point + Vector3(0.1,0,0.12)).normalized(), 0.060, 12)
	else:
		# A warm bakery terrace: a shared table, picnic baskets and orchard edges.
		var terrace := _offset(anchors["home"], -3.45, -0.1)
		_paved_area(terrace, Vector2(1.6, 1.4))
		_route(_offset(anchors["home"], 0, 2.0), _offset(terrace, 0.8, 0.8), 0.45)
		_starter_prop(7, _offset(terrace, -0.1, -0.45), 1.2)
		_starter_prop(3, _offset(terrace, -0.1, 1.10), 1.02, PI)
		_starter_prop(12, _offset(anchors["home"], 2.55, 0.25), 1.2)
		_starter_prop(13, _offset(terrace, -1.55, 0.1), 1.0)
		for point in [Vector3(-0.68,1,0.1), Vector3(0.75,1,0.15), Vector3(0.65,1,-0.9)]:
			_garden_tree(point.normalized(), 1.08)
		for point in [Vector3(-0.55,1,0.55), Vector3(0.58,1,0.70)]:
			_shrub_cluster(point.normalized(), 1.05)
			_flower_bed((point+Vector3(0.1,0,0.1)).normalized(), 0.070, 15)


func _tint_tree(tree: Node3D) -> void:
	# Keep bark distinct while shifting existing leaf forms into each moon's palette.
	for mesh_node in tree.find_children("*", "MeshInstance3D", true, false):
		var source: Material = mesh_node.get_active_material(0)
		if source is StandardMaterial3D:
			var material := source.duplicate() as StandardMaterial3D
			var name_hint := str(mesh_node.name).to_lower()
			var is_wood := "trunk" in name_hint or "branch" in name_hint
			material.albedo_color = Color("827e89") if is_wood else _palette[3].lerp(_palette[4], 0.24)
			mesh_node.material_override = material


func _make_bolt_workbench(direction: Vector3) -> void:
	var bench := Art._root("BoltWorkSurface")
	var wood := _material(Color("b18565"))
	var blue := _material(Color("6b8797"))
	var copper := _material(Color("bc845f"), 0.25)
	var steel := _material(Color("acc9d1"), 0.30)
	var dark := _material(Color("455762"))
	for x in [-0.62, 0.62]:
		for z in [-0.27, 0.27]:
			Art._softbox(bench, "BenchLeg", Vector3(x, 0.34, z), Vector3(0.10, 0.68, 0.10), 0.025, blue)
		Art._rod(bench, "EndRail", Vector3(x, 0.22, -0.27), Vector3(x, 0.22, 0.27), 0.035, blue)
	Art._rod(bench, "LowerRail", Vector3(-0.62, 0.24, 0), Vector3(0.62, 0.24, 0), 0.035, blue)
	for z in [-0.27, 0.0, 0.27]:
		Art._softbox(bench, "BenchPlank", Vector3(0, 0.72, z), Vector3(1.52, 0.12, 0.25), 0.025, wood)
	# A laid-down hammer and a loose gear leave a clear working gap around the repair.
	Art._rod(bench, "HammerHandle", Vector3(-0.55, 0.82, 0.24), Vector3(-0.40, 0.82, -0.12), 0.030, copper)
	var hammer := Art._softbox(bench, "HammerHead", Vector3(-0.40, 0.83, -0.12), Vector3(0.27, 0.10, 0.12), 0.025, steel)
	hammer.rotation.y = -0.39
	var gear_center := Vector3(-0.07, 0.81, 0.19)
	Art._ring(bench, "SpareGear", gear_center, 0.095, 0.026, copper)
	for i in range(6):
		var a := TAU * i / 6.0
		var tooth := Art._softbox(bench, "GearTooth", gear_center + Vector3(cos(a), 0, sin(a)) * 0.108, Vector3(0.065, 0.045, 0.048), 0.010, copper)
		tooth.rotation.y = -a
	# The open housing, exposed coil and separate lid make this an unfinished object.
	Art._softbox(bench, "OpenMechanism", Vector3(0.34, 0.87, -0.06), Vector3(0.38, 0.18, 0.34), 0.045, blue)
	Art._softbox(bench, "MechanismInset", Vector3(0.34, 0.965, -0.06), Vector3(0.27, 0.025, 0.23), 0.025, dark)
	Art._rod(bench, "ExposedAxle", Vector3(0.22, 1.015, -0.06), Vector3(0.44, 1.015, -0.06), 0.025, steel)
	for x in [0.27, 0.33, 0.39]:
		var coil := Art._ring(bench, "CopperCoil", Vector3(x, 1.015, -0.06), 0.055, 0.015, copper)
		coil.rotation.z = PI * 0.5
	Art._softbox(bench, "LooseCover", Vector3(0.40, 0.81, 0.25), Vector3(0.32, 0.035, 0.18), 0.025, blue)
	var footprint := _footprint(bench)
	if not _solid_clear(direction, footprint):
		bench.free()
		return
	_place(bench, direction, 1.0)
	_add_obstacle(direction, footprint)


func _toward(direction: Vector3, target: Vector3) -> float:
	var frame := _frame(direction)
	return atan2(target.dot(frame.x), target.dot(frame.z))


func _offset(direction: Vector3, right: float, forward: float) -> Vector3:
	var frame := _frame(direction)
	return (direction + (frame.x * right + frame.z * forward) / _radius).normalized()


func _shrub_cluster(direction: Vector3, size: float) -> void:
	if not _solid_clear(direction, 0.60 * size):
		return
	_planting_ground(direction, Vector2(0.73, 0.48) * size, _palette[3].darkened(0.36))
	if _style == 0:
		_place(Botany.shrub(), direction, size)
		_add_obstacle(direction, 0.60 * size)
		return
	var frame := _frame(direction)
	for offset in [Vector3(-0.30,0.20,0.04), Vector3(0.03,0.31,-0.09), Vector3(0.33,0.24,0.08), Vector3(-0.12,0.16,0.23)]:
		var n: Vector3 = (direction + (frame.x * offset.x + frame.z * offset.z) * size / _radius).normalized()
		_stamp("leaf", n, Vector3(0.34, 0.29, 0.29) * size / _radius, offset.y * size / _radius, 3)
	_add_obstacle(direction, 0.60 * size)


func _scatter_garden() -> void:
	# A few authored outlying groves replace the even spherical scatter. Large
	# intervening lawns remain available for the player's own arrangements.
	var sites := [Vector3(-1,0.20,0.55), Vector3(0.90,0.05,-0.60), Vector3(-0.25,-0.85,-0.58), Vector3(0.62,-0.55,0.74)]
	for i in range(sites.size()):
		var direction: Vector3 = sites[i].rotated(Vector3.UP, _style * 0.42).normalized()
		if _reserved(direction):
			continue
		_garden_tree(direction, 1.10 if i % 2 == 0 else 0.92)
		_shrub_cluster((direction + _frame(direction).x * 0.14).normalized(), 0.95)
		_flower_bed((direction - _frame(direction).x * 0.09).normalized(), 0.055, 12)


func _stamp(shape: String, direction: Vector3, size: Vector3, height: float, color_index: int) -> void:
	var key := shape + ":" + str(color_index)
	if not _batches.has(key):
		_batches[key] = []
	var basis := _frame(direction).scaled_local(size * _radius)
	_batches[key].append(Transform3D(basis, direction.normalized() * _radius * (1.0 + height)))


func _flush_batches() -> void:
	for key in _batches:
		var parts: PackedStringArray = key.split(":")
		var mesh: PrimitiveMesh
		match parts[0]:
			"box":
				mesh = BoxMesh.new()
			"stem", "roof":
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = 0.0 if parts[0] == "roof" else 0.5
				cylinder.bottom_radius = 1.0 if parts[0] == "roof" else 0.5
				cylinder.height = 1.0
				cylinder.radial_segments = 6 if parts[0] == "roof" else 5
				mesh = cylinder
			_:
				var sphere := SphereMesh.new()
				sphere.radius = 1.0
				sphere.height = 2.0
				sphere.radial_segments = 8
				sphere.rings = 4
				mesh = sphere
		mesh.material = _material(_palette[int(parts[1])], 0.35 if _style == 2 and parts[1] == "5" else 0.0)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = _batches[key].size()
		for i in range(multimesh.instance_count):
			multimesh.set_instance_transform(i, _batches[key][i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Garden_" + key.replace(":", "_")
		instance.multimesh = multimesh
		_root.add_child(instance)
	_batches.clear()
