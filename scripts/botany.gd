class_name OrbitBotany
extends RefCounted
## Clover's representative plants. Dimensions are metres before world placement.
## Closed, opaque vertex-colour geometry; one mesh/material per factory root.

static var _tree_mesh: ArrayMesh
static var _shrub_mesh: ArrayMesh
static var _plant_material: StandardMaterial3D


static func tree() -> Node3D:
	if _tree_mesh == null:
		var data := _geometry()
		var bark := Color("8d7867")
		_branch(data, [Vector3.ZERO, Vector3(-0.025,0.16,0.01), Vector3(0.008,0.46,-0.008), Vector3(-0.035,0.79,0.01), Vector3(0.02,1.12,-0.02), Vector3(0.07,1.37,-0.04)], [0.165,0.105,0.087,0.072,0.046,0.016], bark)
		_branch(data, [Vector3(-0.025,0.76,0), Vector3(-0.17,1.03,0.04), Vector3(-0.33,1.27,0.07)], [0.048,0.034,0.012], bark)
		_branch(data, [Vector3(0,0.88,0), Vector3(0.20,1.12,-0.03), Vector3(0.34,1.39,-0.05)], [0.043,0.028,0.010], bark)
		# Broad overlapping boughs share a crown, with an off-centre upper leader.
		_bough(data, Vector3(-0.235,1.27,0.05), Vector3(0.385,0.405,0.43), 0.35, Color("62a98a"))
		_bough(data, Vector3(0.24,1.32,-0.055), Vector3(0.37,0.395,0.42), 2.10, Color("70b597"))
		_bough(data, Vector3(-0.025,1.51,-0.015), Vector3(0.40,0.375,0.42), 1.15, Color("83c3a1"))
		# A few curved, blunt-tipped leaves describe the boughs' growth direction.
		_leaf(data, Vector3(-0.16,1.48,0.11), Vector3(-0.68,1.41,0.22), 0.13, 0.07, Vector3.UP, Color("78b99a"))
		_leaf(data, Vector3(-0.13,1.67,0.12), Vector3(-0.43,1.56,0.43), 0.14, 0.06, Vector3(0,1,0.3), Color("8ac6a3"))
		_leaf(data, Vector3(0.03,1.72,0.08), Vector3(0.37,1.62,0.37), 0.13, 0.065, Vector3(0,1,0.2), Color("91cba9"))
		_leaf(data, Vector3(0.24,1.49,0.06), Vector3(0.69,1.40,0.16), 0.12, 0.06, Vector3.UP, Color("7bbd9c"))
		_leaf(data, Vector3(-0.09,1.78,-0.06), Vector3(0.15,1.83,-0.29), 0.12, 0.035, Vector3.UP, Color("9bd0aa"))
		_leaf(data, Vector3(-0.14,1.54,-0.13), Vector3(-0.46,1.43,-0.35), 0.12, 0.06, Vector3.UP, Color("7eb898"))
		_leaf(data, Vector3(0.20,1.48,-0.10), Vector3(0.48,1.36,-0.33), 0.12, 0.045, Vector3.UP, Color("72ae92"))
		_leaf(data, Vector3(-0.22,1.32,0.15), Vector3(-0.40,1.19,0.35), 0.10, 0.055, Vector3(0,0.7,0.5), Color("69a78a"))
		_tree_mesh = _finish(data)
	return _root("CloverLeafTree", _tree_mesh)


static func shrub() -> Node3D:
	if _shrub_mesh == null:
		var data := _geometry()
		# Low interlocking foliage covers the stalk junctions and connects the sprays.
		_bough(data, Vector3(-0.13,0.20,0.055), Vector3(0.36,0.23,0.32), 0.8, Color("608f74"))
		_bough(data, Vector3(0.18,0.25,-0.02), Vector3(0.32,0.27,0.33), 2.1, Color("6b9b7c"))
		# Three connected sprays form a low, irregular outline inside the 0.60m collider.
		var crowns: Array[Vector3] = [Vector3(-0.18,0.31,0.03), Vector3(0.12,0.43,-0.10), Vector3(0.22,0.25,0.17)]
		for i in range(crowns.size()):
			var crown := crowns[i]
			var base := Vector3(crown.x * 0.5, 0.035, crown.z * 0.5)
			_branch(data, [base, crown - Vector3(0,0.04,0)], [0.025,0.012], Color("75816a"))
			for j in range(5):
				var a := float(j) * TAU / 5.0 + float(i) * 1.03
				var reach := 0.25 + 0.025 * sin(float(j) * 2.7 + i)
				var tip := crown + Vector3(cos(a) * reach, -0.08 + 0.045 * sin(a + i), sin(a) * reach * 0.80)
				var color := Color("6fa788").lerp(Color("92b989"), 0.22 + 0.17 * i + 0.055 * sin(a))
				_leaf(data, crown - Vector3(0,0.085,0), tip, 0.12, 0.095, Vector3.UP, color)
			_leaf(data, crown - Vector3(0,0.04,0), crown + Vector3(-0.045,0.16,0.06), 0.065, 0.025, Vector3(0,0.5,1), Color("96bf96"))
		_shrub_mesh = _finish(data)
	return _root("CloverLeafShrub", _shrub_mesh)


static func _root(label: String, mesh: ArrayMesh) -> Node3D:
	var root := Node3D.new()
	root.name = label
	var instance := MeshInstance3D.new()
	instance.name = "PlantMesh"
	instance.mesh = mesh
	root.add_child(instance)
	return root


static func _geometry() -> Dictionary:
	return {"vertices": PackedVector3Array(), "normals": PackedVector3Array(), "colors": PackedColorArray()}


static func _finish(data: Dictionary) -> ArrayMesh:
	if _plant_material == null:
		_plant_material = StandardMaterial3D.new()
		_plant_material.vertex_color_use_as_albedo = true
		_plant_material.vertex_color_is_srgb = true
		_plant_material.roughness = 0.88
		_plant_material.metallic_specular = 0.20
		_plant_material.cull_mode = BaseMaterial3D.CULL_BACK
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.vertices
	arrays[Mesh.ARRAY_NORMAL] = data.normals
	arrays[Mesh.ARRAY_COLOR] = data.colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _plant_material)
	return mesh


static func _triangle(data: Dictionary, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var cross_product := (b - a).cross(c - a)
	if cross_product.length_squared() < 0.000000000001:
		return
	# Godot's front face is clockwise. Supplied normals describe the exterior.
	if cross_product.dot(na + nb + nc) > 0.0:
		_triangle(data, a, c, b, na, nc, nb, ca, cc, cb)
		return
	data.vertices.append_array(PackedVector3Array([a,b,c]))
	data.normals.append_array(PackedVector3Array([na,nb,nc]))
	data.colors.append_array(PackedColorArray([ca,cb,cc]))


static func _branch(data: Dictionary, centers: Array[Vector3], radii: Array[float], color: Color) -> void:
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var colors: Array[Color] = []
	const SIDES := 10
	for i in range(centers.size()):
		var axis := (centers[mini(i+1, centers.size()-1)] - centers[maxi(i-1, 0)]).normalized()
		if i == 0 and centers[0].is_zero_approx():
			axis = Vector3.UP
		var right := axis.cross(Vector3.FORWARD).normalized()
		var forward := right.cross(axis).normalized()
		for j in range(SIDES):
			var a := TAU * j / SIDES + 0.045 * i
			var radial := right * cos(a) + forward * sin(a)
			var ridge := 1.0 + 0.06 * cos(a * 3.0 + i * 0.18)
			points.append(centers[i] + radial * radii[i] * ridge)
			normals.append((radial + axis * 0.09).normalized())
			var shade := 0.94 + 0.065 * cos(a * 3.0) + 0.025 * sin(a + i * 0.3)
			colors.append(Color(color.r*shade, color.g*shade, color.b*shade, 1.0))
	for i in range(centers.size()-1):
		for j in range(SIDES):
			var a := i * SIDES + j
			var b := i * SIDES + (j+1) % SIDES
			var c := b + SIDES
			var d := a + SIDES
			_triangle(data, points[a], points[b], points[c], normals[a], normals[b], normals[c], colors[a], colors[b], colors[c])
			_triangle(data, points[a], points[c], points[d], normals[a], normals[c], normals[d], colors[a], colors[c], colors[d])
	for end in [0, centers.size()-1]:
		var normal := (centers[0] - centers[1]).normalized() if end == 0 else (centers[-1] - centers[-2]).normalized()
		if end == 0 and centers[0].is_zero_approx():
			normal = Vector3.DOWN
		for j in range(SIDES):
			_triangle(data, centers[end], points[end*SIDES+j], points[end*SIDES+(j+1)%SIDES], normal, normal, normal, color, color, color)


static func _bough(data: Dictionary, center: Vector3, extent: Vector3, phase: float, color: Color) -> void:
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var colors: Array[Color] = []
	# A deeper tucked underside and rounded shoulder retain the lobed bough outline.
	var levels := [Vector2(-0.65,0.0), Vector2(-0.53,0.48), Vector2(-0.28,0.87), Vector2(0.0,1.0), Vector2(0.32,0.94), Vector2(0.60,0.75), Vector2(0.82,0.52), Vector2(0.95,0.25), Vector2(1.0,0.0)]
	const SIDES := 24
	var faces: Array[Vector3i] = []
	for ring in range(levels.size()):
		var level: Vector2 = levels[ring]
		for j in range(SIDES):
			var a := TAU * j / SIDES
			var lobe := 1.0 + 0.075 * sin(a * 3.0 + phase) + 0.035 * cos(a * 5.0 - phase)
			var p := Vector3(cos(a) * level.y * lobe, level.x, sin(a) * level.y * lobe)
			p.x += level.x * 0.10 * sin(phase)
			p.z += level.x * 0.12 * cos(phase)
			p.y += sin(a * 3.0 + phase) * 0.065 * level.y
			points.append(center + p * extent)
			var vertical := level.x + 0.10
			normals.append(Vector3(cos(a) * level.y / extent.x, vertical / extent.y, sin(a) * level.y / extent.z).normalized())
			var shade := 0.93 + 0.06 * (level.x + 0.53) + 0.025 * sin(a * 3.0 + phase)
			colors.append(Color(color.r * shade, color.g * shade, color.b * shade, 1.0))
	for ring in range(levels.size()-1):
		for j in range(SIDES):
			var a := ring*SIDES+j
			var b := ring*SIDES+(j+1)%SIDES
			var c := b+SIDES
			var d := a+SIDES
			faces.append(Vector3i(a,b,c))
			faces.append(Vector3i(a,c,d))
	_smooth_shell(data, points, faces, normals, colors)


static func _leaf(data: Dictionary, start: Vector3, tip: Vector3, half_width: float, camber: float, up: Vector3, color: Color) -> void:
	var forward := (tip-start).normalized()
	var right := up.cross(forward).normalized()
	var normal := forward.cross(right).normalized()
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var colors: Array[Color] = []
	var faces: Array[Vector3i] = []
	const STEPS := 8
	const SIDES := 12
	var thickness := half_width * 0.31
	# Oval cross sections close into rounded tips. The centreline supplies a gentle
	# bend, while continuous normals cross both blade diagonals and the rolled edge.
	for i in range(STEPS+1):
		var theta := PI * i / STEPS
		var t := 0.5 - 0.5 * cos(theta)
		var profile := sin(theta) if i > 0 and i < STEPS else 0.0
		var bend := sin(PI*t) * camber * 0.72
		var width := profile * half_width * (1.10 - t*0.20)
		for j in range(SIDES):
			var a := TAU * j / SIDES
			points.append(start.lerp(tip,t) + normal*bend + right*cos(a)*width + normal*sin(a)*profile*thickness)
			var hint := right*cos(a)/half_width + normal*sin(a)/thickness
			if i == 0:
				hint = -forward
			elif i == STEPS:
				hint = forward
			normals.append(hint.normalized())
			var shade := 0.96 + 0.045 * sin(a) + 0.015 * profile
			colors.append(Color(color.r*shade,color.g*shade,color.b*shade,1.0))
	for i in range(STEPS):
		for j in range(SIDES):
			var a := i*SIDES+j
			var b := i*SIDES+(j+1)%SIDES
			faces.append(Vector3i(a,b,b+SIDES))
			faces.append(Vector3i(a,b+SIDES,a+SIDES))
	_smooth_shell(data, points, faces, normals, colors)


static func _smooth_shell(data: Dictionary, points: Array[Vector3], faces: Array[Vector3i], hints: Array[Vector3], colors: Array[Color]) -> void:
	var sums: Dictionary = {}
	var keys: Array[Vector3] = []
	var oriented: Array[Vector3i] = []
	for p in points:
		var key := p.snapped(Vector3.ONE * 0.000001)
		keys.append(key)
		sums[key] = Vector3.ZERO
	for face in faces:
		var cross_product := (points[face.y]-points[face.x]).cross(points[face.z]-points[face.x])
		if cross_product.length_squared() < 0.000000000001:
			continue
		if cross_product.dot(hints[face.x]+hints[face.y]+hints[face.z]) > 0.0:
			face = Vector3i(face.x,face.z,face.y)
			cross_product = -cross_product
		oriented.append(face)
		for index in [face.x,face.y,face.z]:
			sums[keys[index]] -= cross_product
	for face in oriented:
		var a: Vector3 = sums[keys[face.x]].normalized()
		var b: Vector3 = sums[keys[face.y]].normalized()
		var c: Vector3 = sums[keys[face.z]].normalized()
		_triangle(data, points[face.x],points[face.y],points[face.z],a,b,c,colors[face.x],colors[face.y],colors[face.z])
