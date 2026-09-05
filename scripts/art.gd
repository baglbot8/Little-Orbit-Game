class_name PlanetArt
extends RefCounted
## Procedural toy miniatures. Feet/bases sit at Y=0; faces and doors face +Z.
## Returned roots are independent, unparented, and contain no scripts or physics.
## Integer variants wrap, including negative values. Dimensions are world units.

const CREAM := Color("fff1d6")
const WHITE := Color("fffaf0")
const MINT := Color("8edcc3")
const TEAL := Color("479c9c")
const PEACH := Color("f3a58e")
const PINK := Color("eeb5d4")
const LILAC := Color("b6a7e0")
const BLUE := Color("93c9e4")
const GOLD := Color("f6ce75")
const INK := Color("30485d")
const SOIL := Color("846b81")


static func _material(color: Color, shiny: bool = false, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.28 if shiny else 0.66
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat


static func _root(label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	return node


static func _mesh(parent: Node3D, label: String, shape: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = shape
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node


static func _ball(parent: Node3D, label: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var node := _mesh(parent, label, mesh, pos, mat)
	node.scale = size
	return node


static func _tube(parent: Node3D, label: String, pos: Vector3, radius: float, height: float, mat: Material, top: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = 32
	return _mesh(parent, label, mesh, pos, mat)


static func _capsule(parent: Node3D, label: String, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 20
	mesh.rings = 8
	return _mesh(parent, label, mesh, pos, mat)


static func _rod(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var delta := b - a
	var node := _capsule(parent, label, (a + b) * 0.5, radius, delta.length() + radius * 2.0, mat)
	if delta.length_squared() > 0.000001:
		node.quaternion = Quaternion(Vector3.UP, delta.normalized())
	return node


## Rounded box assembled from flat faces, cylindrical edges, and spherical corners.
static func _softbox(parent: Node3D, label: String, pos: Vector3, size: Vector3, radius: float, mat: Material) -> Node3D:
	var root := _root(label)
	parent.add_child(root)
	root.position = pos
	var r := minf(radius, minf(size.x, minf(size.y, size.z)) * 0.49)
	var core := size * 0.5 - Vector3.ONE * r
	for axis in range(3):
		var box := BoxMesh.new()
		var dimensions := size - Vector3.ONE * r * 2.0
		dimensions[axis] = size[axis]
		box.size = dimensions
		_mesh(root, "Face", box, Vector3.ZERO, mat)
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				_ball(root, "Corner", Vector3(x, y, z) * core, Vector3.ONE * r * 2.0, mat)
	for axis in range(3):
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for a in [-1.0, 1.0]:
			for b in [-1.0, 1.0]:
				var p := Vector3.ZERO
				p[u] = a * core[u]
				p[v] = b * core[v]
				var mesh := CylinderMesh.new()
				mesh.top_radius = r
				mesh.bottom_radius = r
				mesh.height = core[axis] * 2.0
				mesh.radial_segments = 12
				var edge := _mesh(root, "Edge", mesh, p, mat)
				var direction := Vector3.ZERO
				direction[axis] = 1.0
				edge.quaternion = Quaternion(Vector3.UP, direction)
	return root


static func _ring(parent: Node3D, label: String, pos: Vector3, radius: float, thickness: float, mat: Material, front: bool = false) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 32
	mesh.ring_segments = 12
	var node := _mesh(parent, label, mesh, pos, mat)
	if front:
		node.rotation.x = PI * 0.5
	return node


static func _eyes(parent: Node3D, center: Vector3, spacing: float, size: float) -> void:
	var dark := _material(INK, true)
	var light := _material(WHITE, true)
	for side in [-1.0, 1.0]:
		var p := center + Vector3(side * spacing * 0.5, 0, 0)
		_ball(parent, "Eye", p, Vector3(size, size * 1.25, size * 0.45), dark)
		_ball(parent, "EyeGlint", p + Vector3(-size * 0.13, size * 0.2, size * 0.22), Vector3.ONE * size * 0.23, light)


static func _star(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> Node3D:
	var root := _root("Star")
	parent.add_child(root)
	root.position = pos
	_ball(root, "Heart", Vector3.ZERO, Vector3(radius, radius, radius * 0.48), mat)
	for i in range(5):
		var angle := TAU * float(i) / 5.0
		var direction := Vector3(sin(angle), cos(angle), 0)
		var petal := _ball(root, "Point", direction * radius * 0.43, Vector3(radius * 0.48, radius * 1.14, radius * 0.4), mat)
		petal.rotation.z = -angle
	return root


# Character-only helpers. Rig pivots are local; +Z is the face direction.
static func _pivot(parent: Node3D, label: String, pos: Vector3) -> Node3D:
	var node := _root(label)
	parent.add_child(node)
	node.position = pos
	return node


static func _accent(node: Node3D) -> Node3D:
	if node is MeshInstance3D:
		node.set_meta("suit_accent", true)
	for child in node.get_children():
		_accent(child)
	return node


static func _smile(parent: Node3D, center: Vector3, width: float, depth: float, mat: Material) -> void:
	for i in range(10):
		var x0 := float(i) / 10.0 * 2.0 - 1.0
		var x1 := float(i + 1) / 10.0 * 2.0 - 1.0
		_rod(parent, "Smile", center + Vector3(x0 * width * 0.5, depth * x0 * x0, 0), center + Vector3(x1 * width * 0.5, depth * x1 * x1, 0), 0.006, mat)


static func astronaut() -> Node3D:
	var root := _root("Astronaut")
	var suit := _material(CREAM)
	var trim := _material(PEACH)
	var dark := _material(INK, true)
	var blue := _material(BLUE, true)
	var mint := _material(MINT)
	var white := _material(WHITE, true)
	_ball(root, "Suit", Vector3(0, 0.43, 0), Vector3(0.41, 0.41, 0.32), suit)
	_accent(_ring(root, "WaistSeam", Vector3(0, 0.325, 0), 0.155, 0.014, trim)).scale.z = 0.80
	_softbox(root, "LifeSupport", Vector3(0, 0.45, -0.19), Vector3(0.29, 0.30, 0.16), 0.045, suit)
	_accent(_softbox(root, "PackPanel", Vector3(0, 0.46, -0.277), Vector3(0.21, 0.22, 0.025), 0.012, trim))
	for i in range(3):
		_rod(root, "PackVent", Vector3(-0.065, 0.42 + i * 0.027, -0.295), Vector3(0.065, 0.42 + i * 0.027, -0.295), 0.007, dark)
	for side in [-1.0, 1.0]:
		var suffix := "Left" if side < 0 else "Right"
		var leg := _pivot(root, "Leg" + suffix, Vector3(side * 0.105, 0.285, 0))
		_capsule(leg, "Trouser", Vector3(0, -0.082, 0), 0.077, 0.24, suit)
		_accent(_tube(leg, "AnkleCuff", Vector3(0, -0.15, 0), 0.08, 0.042, trim))
		_ball(leg, "Boot", Vector3(0, -0.205, 0.035), Vector3(0.185, 0.125, 0.25), suit)
		_softbox(leg, "BootSole", Vector3(0, -0.265, 0.038), Vector3(0.184, 0.04, 0.246), 0.018, dark)
		_accent(_ball(leg, "ToeGuard", Vector3(0, -0.205, 0.118), Vector3(0.16, 0.067, 0.067), trim))
		var arm := _pivot(root, "Arm" + suffix, Vector3(side * 0.205, 0.535, 0))
		_ball(arm, "Shoulder", Vector3.ZERO, Vector3(0.145, 0.15, 0.15), suit)
		_rod(arm, "Sleeve", Vector3(0, -0.02, 0), Vector3(side * 0.055, -0.155, 0.022), 0.063, suit)
		_accent(_tube(arm, "WristCuff", Vector3(side * 0.06, -0.163, 0.025), 0.065, 0.039, trim))
		_ball(arm, "Mitten", Vector3(side * 0.066, -0.214, 0.035), Vector3(0.12, 0.12, 0.135), suit)
		_ball(arm, "Thumb", Vector3(side * 0.023, -0.204, 0.075), Vector3(0.055, 0.067, 0.06), suit)
		_ball(arm, "ShoulderPatch", Vector3(0, 0.007, 0.074), Vector3(0.075, 0.074, 0.012), blue)
		_star(arm, Vector3(0, 0.007, 0.085), 0.023, white)
		_capsule(root, "PackTank", Vector3(side * 0.145, 0.45, -0.18), 0.044, 0.235, mint)
		_rod(root, "HarnessSeam", Vector3(side * 0.125, 0.51, 0.126), Vector3(side * 0.12, 0.365, 0.133), 0.009, trim)
	_ring(root, "CollarSeal", Vector3(0, 0.603, 0), 0.135, 0.022, dark)
	_accent(_ring(root, "Collar", Vector3(0, 0.625, 0), 0.15, 0.023, trim))
	var head := _pivot(root, "HeadRig", Vector3(0, 0.625, 0))
	_ball(head, "Helmet", Vector3(0, 0.175, 0), Vector3(0.52, 0.47, 0.45), suit)
	_accent(_ball(head, "VisorRim", Vector3(0, 0.174, 0.17), Vector3(0.444, 0.337, 0.17), trim))
	_ball(head, "VisorGasket", Vector3(0, 0.177, 0.197), Vector3(0.405, 0.297, 0.15), white)
	_ball(head, "Visor", Vector3(0, 0.179, 0.219), Vector3(0.378, 0.273, 0.13), dark)
	_ball(head, "VisorReflection", Vector3(-0.09, 0.247, 0.271), Vector3(0.10, 0.039, 0.012), blue).rotation.z = 0.35
	_ball(head, "VisorSpark", Vector3(-0.129, 0.214, 0.269), Vector3(0.023, 0.034, 0.008), white)
	_ball(head, "VisorLowerBounce", Vector3(0.092, 0.096, 0.268), Vector3(0.087, 0.012, 0.008), blue).rotation.z = 0.3
	for side in [-1.0, 1.0]:
		_ball(head, "HelmetHinge", Vector3(side * 0.243, 0.15, 0.035), Vector3(0.045, 0.108, 0.11), mint)
	_softbox(root, "ConsoleFrame", Vector3(0, 0.458, 0.155), Vector3(0.195, 0.145, 0.042), 0.018, suit)
	_softbox(root, "ChestConsole", Vector3(0, 0.458, 0.18), Vector3(0.164, 0.116, 0.018), 0.008, mint)
	_softbox(root, "ConsoleDisplay", Vector3(-0.022, 0.475, 0.193), Vector3(0.093, 0.035, 0.008), 0.003, dark)
	_rod(root, "Readout", Vector3(-0.055, 0.475, 0.20), Vector3(0.006, 0.475, 0.20), 0.004, blue)
	for i in range(3):
		_ball(root, "Button", Vector3(-0.05 + i * 0.05, 0.429, 0.195), Vector3.ONE * 0.018, _material([PEACH, GOLD, WHITE][i]))
	return root


# Neighbor IDs are stable save-data identities; main applies the shared 1.2 scale.
# New miniatures keep the same ~0.36 local standing radius and Y=0 feet.
static func neighbor(id: int) -> Node3D:
	match posmod(id, 4):
		0: return alien()
		1: return robot()
		2: return _pip()
	return _miso()


static func _pip() -> Node3D:
	var root := _root("PipCourier")
	var sky := _material(Color("79bde8"))
	var seam := _material(Color("437ca8"))
	var cream := _material(CREAM)
	var amber := _material(Color("c39361"))
	var dark := _material(INK, true)
	var light := _material(WHITE, true)
	_ball(root, "PaddedFlightSuit", Vector3(0, 0.34, 0), Vector3(0.36, 0.36, 0.29), sky)
	_ring(root, "SuitBelt", Vector3(0, 0.28, 0), 0.154, 0.017, seam).scale.z = 0.84
	_softbox(root, "MapPocket", Vector3(-0.04, 0.385, 0.14), Vector3(0.13, 0.10, 0.026), 0.01, cream)
	_star(root, Vector3(-0.04, 0.388, 0.159), 0.028, amber)
	for side in [-1.0, 1.0]:
		var suffix := "Left" if side < 0 else "Right"
		var leg := _pivot(root, "Leg" + suffix, Vector3(side * 0.09, 0.22, 0))
		_capsule(leg, "SuitLeg", Vector3(0, -0.055, 0), 0.065, 0.18, sky)
		_tube(leg, "BootCuff", Vector3(0, -0.13, 0), 0.071, 0.035, cream)
		_ball(leg, "MoonBoot", Vector3(0, -0.16, 0.025), Vector3(0.16, 0.12, 0.22), seam)
		var arm := _pivot(root, "Arm" + suffix, Vector3(side * 0.175, 0.43, 0))
		_ball(arm, "Shoulder", Vector3.ZERO, Vector3.ONE * 0.12, sky)
		_rod(arm, "Sleeve", Vector3.ZERO, Vector3(side * 0.055, -0.14, 0.012), 0.052, sky)
		_ball(arm, "Glove", Vector3(side * 0.057, -0.17, 0.025), Vector3(0.10, 0.10, 0.11), cream)
		_ball(arm, "Thumb", Vector3(side * 0.025, -0.15, 0.07), Vector3.ONE * 0.039, cream)
	# The low left satchel is separate geometry, with an envelope under its flap.
	_softbox(root, "CourierSatchel", Vector3(-0.195, 0.275, -0.075), Vector3(0.19, 0.21, 0.14), 0.035, amber)
	_softbox(root, "Letter", Vector3(-0.195, 0.363, -0.025), Vector3(0.12, 0.066, 0.014), 0.006, cream)
	_softbox(root, "SatchelFlap", Vector3(-0.195, 0.313, 0.003), Vector3(0.17, 0.10, 0.025), 0.012, seam)
	_ball(root, "BagClasp", Vector3(-0.195, 0.287, 0.019), Vector3.ONE * 0.025, cream)
	_rod(root, "CrossBodyStrap", Vector3(0.115, 0.49, 0.124), Vector3(-0.165, 0.27, 0.133), 0.016, amber)
	_ring(root, "HelmetSeal", Vector3(0, 0.49, 0), 0.13, 0.024, cream)
	var head := _pivot(root, "HeadRig", Vector3(0, 0.50, 0))
	_ball(head, "RoundHelmet", Vector3(0, 0.19, 0), Vector3(0.49, 0.45, 0.43), sky)
	_ball(head, "VisorRim", Vector3(0, 0.18, 0.16), Vector3(0.425, 0.325, 0.17), cream)
	_ball(head, "Visor", Vector3(0, 0.18, 0.194), Vector3(0.378, 0.28, 0.12), dark)
	for side in [-1.0, 1.0]:
		var eye := _pivot(head, "EyeLeft" if side < 0 else "EyeRight", Vector3(side * 0.077, 0.20, 0.253))
		_ball(eye, "BrightEye", Vector3.ZERO, Vector3(0.042, 0.071, 0.014), light)
		_ball(head, "Cheek", Vector3(side * 0.119, 0.135, 0.242), Vector3(0.046, 0.018, 0.012), _material(PEACH))
		_ball(head, "HelmetEarpiece", Vector3(side * 0.233, 0.17, 0), Vector3(0.046, 0.12, 0.12), seam)
	_smile(head, Vector3(0, 0.118, 0.254), 0.060, 0.015, light)
	var aerial := _pivot(head, "AerialRig", Vector3(0.16, 0.35, -0.03))
	_rod(aerial, "Aerial", Vector3.ZERO, Vector3(0.04, 0.17, 0), 0.011, seam)
	_ball(aerial, "SignalPearl", Vector3(0.04, 0.18, 0), Vector3.ONE * 0.055, _material(GOLD))
	return root


static func _miso() -> Node3D:
	var root := _root("MisoBaker")
	var cream := _material(CREAM)
	var amber := _material(Color("dfaa62"))
	var toast := _material(Color("a97650"))
	var apron := _material(Color("b6c6a0"))
	var dark := _material(INK, true)
	_ball(root, "RoundOvenBody", Vector3(0, 0.34, 0), Vector3(0.43, 0.39, 0.34), amber)
	_ball(root, "ApronSkirt", Vector3(0, 0.305, 0.139), Vector3(0.32, 0.27, 0.085), cream)
	_softbox(root, "ApronBib", Vector3(0, 0.43, 0.151), Vector3(0.19, 0.16, 0.035), 0.016, cream)
	_softbox(root, "ApronPocket", Vector3(0, 0.305, 0.186), Vector3(0.13, 0.073, 0.02), 0.009, apron)
	for side in [-1.0, 1.0]:
		var suffix := "Left" if side < 0 else "Right"
		var leg := _pivot(root, "Leg" + suffix, Vector3(side * 0.10, 0.185, 0))
		_tube(leg, "AnklePiston", Vector3(0, -0.05, 0), 0.044, 0.10, toast)
		_ball(leg, "BakerClog", Vector3(0, -0.13, 0.028), Vector3(0.18, 0.11, 0.235), cream)
		var arm := _pivot(root, "Arm" + suffix, Vector3(side * 0.205, 0.43, 0))
		_ball(arm, "Swivel", Vector3.ZERO, Vector3.ONE * 0.09, toast)
		_capsule(arm, "RoundedArm", Vector3(side * 0.025, -0.075, 0), 0.048, 0.16, amber)
		_ball(arm, "OvenMitt", Vector3(side * 0.037, -0.165, 0.02), Vector3(0.115, 0.13, 0.11), apron)
		_ball(arm, "MittThumb", Vector3(side * 0.001, -0.144, 0.055), Vector3.ONE * 0.045, apron)
		_rod(root, "ApronStrap", Vector3(side * 0.079, 0.48, 0.087), Vector3(side * 0.079, 0.417, 0.177), 0.013, cream)
	_tube(root, "NeckBearing", Vector3(0, 0.535, 0), 0.075, 0.068, toast)
	var head := _pivot(root, "HeadRig", Vector3(0, 0.55, 0))
	_ball(head, "CreamHead", Vector3(0, 0.16, 0), Vector3(0.48, 0.34, 0.35), cream)
	_ball(head, "AmberFaceRim", Vector3(0, 0.145, 0.143), Vector3(0.377, 0.241, 0.09), amber)
	_ball(head, "Face", Vector3(0, 0.145, 0.172), Vector3(0.335, 0.206, 0.055), dark)
	for side in [-1.0, 1.0]:
		var eye := _pivot(head, "EyeLeft" if side < 0 else "EyeRight", Vector3(side * 0.07, 0.161, 0.202))
		_ball(eye, "WarmEye", Vector3.ZERO, Vector3(0.040, 0.057, 0.012), _material(GOLD, true, 0.15))
		_ball(head, "Freckle", Vector3(side * 0.12, 0.111, 0.19), Vector3(0.033, 0.02, 0.011), _material(PEACH))
	_smile(head, Vector3(0, 0.093, 0.204), 0.063, 0.016, cream)
	# A tilted chef's toque encircled by a small Saturn brim.
	var cap := _pivot(head, "ChefCap", Vector3(0, 0.309, -0.018))
	cap.rotation.z = -0.10
	_tube(cap, "ToqueBand", Vector3(0, 0.029, 0), 0.147, 0.073, amber)
	_ring(cap, "OrbitalBrim", Vector3(0, 0.045, 0), 0.228, 0.016, toast).scale.z = 0.82
	for x in [-0.095, 0.0, 0.095]:
		_ball(cap, "ChefPuff", Vector3(x, 0.105 + (0.03 if x == 0 else 0), 0), Vector3(0.18, 0.18, 0.22), cream)
	_ball(cap, "OrbitCrumb", Vector3(0.206, 0.045, 0.06), Vector3.ONE * 0.047, amber)
	return root


static func alien() -> Node3D:
	var root := _root("Alien")
	var skin := _material(MINT)
	var coral := _material(PEACH)
	var cream := _material(CREAM)
	var cloth := _material(BLUE)
	var dark := _material(INK, true)
	var white := _material(WHITE, true)
	_accent(_ball(root, "Romper", Vector3(0, 0.33, 0), Vector3(0.37, 0.35, 0.29), cloth))
	_ball(root, "Bib", Vector3(0, 0.371, 0.131), Vector3(0.235, 0.20, 0.035), cream)
	_ring(root, "SoftCollar", Vector3(0, 0.478, 0), 0.109, 0.022, cream)
	_star(root, Vector3(0, 0.365, 0.156), 0.047, coral)
	for side in [-1.0, 1.0]:
		var suffix := "Left" if side < 0 else "Right"
		var leg := _pivot(root, "Leg" + suffix, Vector3(side * 0.102, 0.225, 0))
		_accent(_capsule(leg, "RomperLeg", Vector3(0, -0.048, 0), 0.071, 0.17, cloth))
		_tube(leg, "FoldedHem", Vector3(0, -0.10, 0), 0.074, 0.035, cream)
		_ball(leg, "Boot", Vector3(0, -0.153, 0.038), Vector3(0.18, 0.114, 0.24), coral)
		_softbox(leg, "Sole", Vector3(0, -0.211, 0.038), Vector3(0.17, 0.028, 0.23), 0.012, cream)
		var arm := _pivot(root, "Arm" + suffix, Vector3(side * 0.178, 0.429, 0))
		_accent(_ball(arm, "PuffSleeve", Vector3(side * 0.02, -0.026, 0), Vector3(0.12, 0.13, 0.13), cloth))
		_rod(arm, "Forearm", Vector3(side * 0.035, -0.06, 0), Vector3(side * 0.072, -0.126, 0.028), 0.044, skin)
		_ball(arm, "Hand", Vector3(side * 0.077, -0.15, 0.035), Vector3(0.10, 0.105, 0.105), skin)
		_ball(arm, "Thumb", Vector3(side * 0.04, -0.14, 0.06), Vector3.ONE * 0.045, skin)
		_ball(root, "BibButton", Vector3(side * 0.077, 0.423, 0.146), Vector3.ONE * 0.022, coral)
	var head := _pivot(root, "HeadRig", Vector3(0, 0.49, 0))
	_ball(head, "Head", Vector3(0, 0.207, 0), Vector3(0.565, 0.416, 0.395), skin)
	for side in [-1.0, 1.0]:
		var suffix := "Left" if side < 0 else "Right"
		_ball(head, "Ear", Vector3(side * 0.258, 0.175, -0.008), Vector3(0.115, 0.14, 0.09), skin).rotation.z = side * -0.4
		var antenna_base := Vector3(side * 0.135, 0.373, -0.012)
		var antenna := _pivot(head, "Antenna" + suffix, antenna_base)
		_rod(antenna, "Antenna", Vector3.ZERO, Vector3(side * 0.195, 0.525, -0.01) - antenna_base, 0.019, skin)
		_ball(antenna, "AntennaPearl", Vector3(side * 0.195, 0.525, -0.01) - antenna_base, Vector3(0.086, 0.095, 0.086), coral)
		_ball(antenna, "PearlGlint", Vector3(side * 0.195 - 0.012, 0.547, 0.025) - antenna_base, Vector3.ONE * 0.019, cream)
		var eye := _pivot(head, "Eye" + suffix, Vector3(side * 0.103, 0.226, 0.176))
		_ball(eye, "Eye", Vector3.ZERO, Vector3(0.078, 0.108, 0.044), dark)
		_ball(eye, "Glint", Vector3(-0.013, 0.023, 0.022), Vector3.ONE * 0.023, white)
		_ball(eye, "SmallGlint", Vector3(0.012, -0.02, 0.022), Vector3.ONE * 0.01, white)
		_rod(head, "Brow", Vector3(side * 0.078, 0.307, 0.15), Vector3(side * 0.126, 0.303, 0.143), 0.008, _material(TEAL))
		_ball(head, "Cheek", Vector3(side * 0.171, 0.156, 0.156), Vector3(0.074, 0.033, 0.018), coral)
	_ball(head, "Nose", Vector3(0, 0.18, 0.196), Vector3(0.034, 0.027, 0.026), skin)
	_smile(head, Vector3(0, 0.125, 0.187), 0.073, 0.017, dark)
	return root


static func robot() -> Node3D:
	var root := _root("Robot")
	var shell := _material(BLUE)
	var joint := _material(TEAL)
	var cream := _material(CREAM)
	var coral := _material(PEACH)
	var dark := _material(INK, true)
	var light := _material(MINT, true, 0.35)
	_accent(_softbox(root, "Body", Vector3(0, 0.39, 0), Vector3(0.35, 0.30, 0.28), 0.065, shell))
	_softbox(root, "BellyPanel", Vector3(0, 0.393, 0.143), Vector3(0.24, 0.185, 0.022), 0.01, cream)
	for side in [-1.0, 1.0]:
		var suffix := "Left" if side < 0 else "Right"
		var leg := _pivot(root, "Leg" + suffix, Vector3(side * 0.103, 0.25, 0))
		_ball(leg, "HipJoint", Vector3.ZERO, Vector3.ONE * 0.083, joint)
		_capsule(leg, "Piston", Vector3(0, -0.072, 0), 0.036, 0.155, cream)
		_tube(leg, "KneeBand", Vector3(0, -0.07, 0), 0.046, 0.03, joint)
		_accent(_softbox(leg, "Boot", Vector3(0, -0.18, 0.035), Vector3(0.176, 0.105, 0.238), 0.042, shell))
		_softbox(leg, "Sole", Vector3(0, -0.233, 0.035), Vector3(0.177, 0.034, 0.239), 0.015, joint)
		_softbox(leg, "ToeStripe", Vector3(0, -0.166, 0.149), Vector3(0.10, 0.022, 0.01), 0.004, cream)
		var arm := _pivot(root, "Arm" + suffix, Vector3(side * 0.207, 0.465, 0))
		_ball(arm, "ShoulderJoint", Vector3.ZERO, Vector3.ONE * 0.104, joint)
		_accent(_capsule(arm, "ArmShell", Vector3(side * 0.034, -0.083, 0), 0.047, 0.145, shell))
		_ball(arm, "Elbow", Vector3(side * 0.042, -0.13, 0.012), Vector3.ONE * 0.074, cream)
		_tube(arm, "Wrist", Vector3(side * 0.043, -0.166, 0.02), 0.036, 0.039, joint)
		_ball(arm, "Hand", Vector3(side * 0.044, -0.208, 0.025), Vector3(0.095, 0.083, 0.085), cream)
		for finger in [-1.0, 1.0]:
			_capsule(arm, "Gripper", Vector3(side * 0.044 + finger * 0.027, -0.242, 0.042), 0.018, 0.048, coral)
		_ball(arm, "ShoulderBolt", Vector3(0, 0, 0.055), Vector3(0.035, 0.035, 0.012), cream)
	_tube(root, "Neck", Vector3(0, 0.566, 0), 0.061, 0.085, joint)
	_ring(root, "NeckWasher", Vector3(0, 0.571, 0), 0.066, 0.008, cream)
	var head := _pivot(root, "HeadRig", Vector3(0, 0.586, 0))
	_softbox(head, "Head", Vector3(0, 0.158, 0), Vector3(0.49, 0.325, 0.33), 0.077, cream)
	_accent(_softbox(head, "ScreenBezel", Vector3(0, 0.153, 0.155), Vector3(0.424, 0.256, 0.041), 0.02, shell))
	_softbox(head, "FaceScreen", Vector3(0, 0.156, 0.18), Vector3(0.381, 0.216, 0.038), 0.018, dark)
	for side in [-1.0, 1.0]:
		var suffix := "Left" if side < 0 else "Right"
		var eye := _pivot(head, "Eye" + suffix, Vector3(side * 0.082, 0.176, 0.204))
		_ball(eye, "PixelEye", Vector3.ZERO, Vector3(0.042, 0.062, 0.012), light)
		_ball(eye, "Glint", Vector3(-0.007, 0.014, 0.007), Vector3.ONE * 0.01, _material(WHITE, true))
		_rod(head, "CheekLight", Vector3(side * 0.116, 0.115, 0.203), Vector3(side * 0.141, 0.115, 0.203), 0.005, coral)
		_ball(head, "EarPod", Vector3(side * 0.246, 0.147, 0), Vector3(0.058, 0.128, 0.14), joint)
		_ball(head, "EarBolt", Vector3(side * 0.265, 0.147, 0.041), Vector3(0.034, 0.045, 0.034), coral)
	_smile(head, Vector3(0, 0.10, 0.204), 0.085, 0.019, light)
	_rod(head, "ScreenGlint", Vector3(-0.143, 0.231, 0.202), Vector3(-0.107, 0.231, 0.202), 0.004, _material(BLUE))
	var aerial_base := Vector3(0.035, 0.322, 0)
	var aerial := _pivot(head, "AerialRig", aerial_base)
	_rod(aerial, "Aerial", Vector3.ZERO, Vector3(0.064, 0.421, 0) - aerial_base, 0.014, joint)
	_ball(aerial, "Signal", Vector3(0.064, 0.421, 0) - aerial_base, Vector3.ONE * 0.069, coral)
	_ring(root, "HeartRim", Vector3(0, 0.41, 0.165), 0.048, 0.009, joint, true)
	_ball(root, "Heart", Vector3(0, 0.41, 0.169), Vector3(0.071, 0.071, 0.016), light)
	for i in range(3):
		_ball(root, "ChargeDot", Vector3(-0.039 + i * 0.039, 0.34, 0.162), Vector3.ONE * 0.013, coral)
	_softbox(root, "ServicePanel", Vector3(0, 0.395, -0.146), Vector3(0.21, 0.19, 0.02), 0.009, cream)
	for side in [-1.0, 1.0]:
		_ball(root, "PanelBolt", Vector3(side * 0.08, 0.456, -0.16), Vector3.ONE * 0.018, joint)
	return root


static func rocket() -> Node3D:
	var root := _root("Rocket")
	var coral := _material(PEACH)
	var cream := _material(CREAM)
	_ball(root, "Fuselage", Vector3(0, 0.97, 0), Vector3(0.77, 1.52, 0.77), cream)
	_ball(root, "NoseCone", Vector3(0, 1.62, 0), Vector3(0.57, 0.59, 0.57), coral)
	_tube(root, "Engine", Vector3(0, 0.25, 0), 0.24, 0.23, _material(TEAL), 0.18)
	_ring(root, "EngineLip", Vector3(0, 0.15, 0), 0.23, 0.027, _material(GOLD))
	for i in range(3):
		var angle := TAU * float(i) / 3.0 + PI
		var fin := _root("LandingFin")
		root.add_child(fin)
		fin.rotation.y = angle
		var shape := _ball(fin, "Fin", Vector3(0, 0.39, 0.37), Vector3(0.16, 0.72, 0.42), coral)
		shape.rotation.x = -0.3
		_ball(fin, "LandingPad", Vector3(0, 0.065, 0.49), Vector3(0.25, 0.13, 0.28), _material(TEAL))
	_ball(root, "PortholeGlass", Vector3(0, 1.14, 0.366), Vector3(0.34, 0.34, 0.065), _material(INK, true))
	_ring(root, "PortholeFrame", Vector3(0, 1.14, 0.39), 0.183, 0.038, _material(GOLD), true)
	_ball(root, "GlassGlint", Vector3(-0.06, 1.21, 0.409), Vector3(0.10, 0.045, 0.014), _material(BLUE))
	_star(root, Vector3(0, 0.72, 0.383), 0.10, coral)
	return root


static func _flower(parent: Node3D, pos: Vector3, height: float, color: Color) -> void:
	var green := _material(TEAL)
	_rod(parent, "Stem", pos, pos + Vector3(0, height, 0), 0.012, green)
	var leaf := _ball(parent, "Leaf", pos + Vector3(0.045, height * 0.46, 0), Vector3(0.12, 0.045, 0.055), _material(MINT))
	leaf.rotation.z = 0.45
	var center := pos + Vector3(0, height, 0)
	var petals := _material(color)
	for i in range(5):
		var angle := TAU * float(i) / 5.0
		_ball(parent, "Petal", center + Vector3(cos(angle), sin(angle), 0) * 0.055, Vector3(0.083, 0.083, 0.046), petals)
	_ball(parent, "Pollen", center + Vector3(0, 0, 0.028), Vector3.ONE * 0.052, _material(GOLD))


static func decoration(kind: int) -> Node3D:
	var variant := posmod(kind, 18)
	if variant >= 6:
		return _new_decoration(variant)
	var root := _root(["MushroomLamp", "StarSculpture", "RobotPlanter", "Bench", "Antenna", "FlowerGarden"][variant])
	var cream := _material(CREAM)
	var teal := _material(TEAL)
	match variant:
		0:
			_tube(root, "Foot", Vector3(0, 0.045, 0), 0.25, 0.09, teal)
			_capsule(root, "Stem", Vector3(0, 0.31, 0), 0.085, 0.55, cream)
			_ball(root, "LuminousGills", Vector3(0, 0.54, 0), Vector3(0.57, 0.10, 0.57), _material(GOLD, false, 0.65))
			_ball(root, "MushroomCap", Vector3(0, 0.61, 0), Vector3(0.67, 0.29, 0.67), _material(PEACH))
			for i in range(6):
				var angle := TAU * float(i) / 6.0
				_ball(root, "CapDot", Vector3(cos(angle) * 0.205, 0.719, sin(angle) * 0.205), Vector3(0.095, 0.029, 0.095), cream)
			_ball(root, "TopDot", Vector3(0, 0.751, 0), Vector3(0.13, 0.024, 0.13), cream)
		1:
			_tube(root, "Plinth", Vector3(0, 0.075, 0), 0.29, 0.15, _material(LILAC))
			_tube(root, "PlinthTop", Vector3(0, 0.17, 0), 0.23, 0.06, cream)
			_rod(root, "Stand", Vector3(0, 0.20, 0), Vector3(0, 0.55, 0), 0.034, teal)
			_star(root, Vector3(0, 0.73, 0), 0.32, _material(GOLD, true))
			_eyes(root, Vector3(0, 0.74, 0.081), 0.11, 0.027)
		2:
			for side in [-1.0, 1.0]:
				_ball(root, "Foot", Vector3(side * 0.13, 0.055, 0.035), Vector3(0.18, 0.11, 0.22), teal)
				_ring(root, "Handle", Vector3(side * 0.255, 0.28, 0), 0.072, 0.025, _material(GOLD), true)
			_softbox(root, "Pot", Vector3(0, 0.25, 0), Vector3(0.43, 0.35, 0.35), 0.065, _material(BLUE))
			_softbox(root, "Soil", Vector3(0, 0.427, 0), Vector3(0.32, 0.018, 0.25), 0.008, _material(SOIL))
			_eyes(root, Vector3(0, 0.27, 0.18), 0.16, 0.044)
			for i in range(3):
				_flower(root, Vector3((i - 1) * 0.105, 0.44, 0), 0.19 + 0.09 * (i % 2), [PINK, GOLD, PEACH][i])
		3:
			for x in [-0.38, 0.38]:
				for z in [-0.13, 0.13]:
					_capsule(root, "Leg", Vector3(x, 0.17, z), 0.04, 0.34, teal)
				_rod(root, "BackPost", Vector3(x, 0.28, -0.15), Vector3(x, 0.67, -0.19), 0.035, teal)
			for z in [-0.13, 0.0, 0.13]:
				_softbox(root, "SeatSlat", Vector3(0, 0.34, z), Vector3(1.0, 0.08, 0.115), 0.028, cream)
			for y in [0.51, 0.65]:
				_softbox(root, "BackSlat", Vector3(0, y, -0.18), Vector3(1.0, 0.115, 0.065), 0.023, _material(PEACH))
		4:
			_tube(root, "Base", Vector3(0, 0.08, 0), 0.24, 0.16, _material(LILAC), 0.19)
			_capsule(root, "Mast", Vector3(0, 0.66, 0), 0.035, 1.18, cream)
			_ring(root, "Orbit", Vector3(0, 1.12, 0), 0.23, 0.019, _material(GOLD), true).rotation.z = 0.35
			_ball(root, "Receiver", Vector3(0, 1.12, 0), Vector3.ONE * 0.16, _material(PEACH))
			_ball(root, "OrbitBead", Vector3(0.21, 1.21, 0), Vector3.ONE * 0.085, _material(MINT))
			_ball(root, "Beacon", Vector3(0, 1.30, 0), Vector3.ONE * 0.09, _material(PINK, false, 0.4))
		5:
			_softbox(root, "GardenBed", Vector3(0, 0.07, 0), Vector3(0.90, 0.14, 0.60), 0.065, _material(PEACH))
			_softbox(root, "Earth", Vector3(0, 0.14, 0), Vector3(0.78, 0.035, 0.48), 0.016, _material(SOIL))
			for i in range(7):
				var x := float(i % 4) * 0.20 - 0.30
				var z := -0.13 if i < 4 else 0.12
				_flower(root, Vector3(x, 0.16, z), 0.19 + float(i % 3) * 0.065, [PINK, CREAM, LILAC, PEACH][i % 4])
	return root


static func _window(parent: Node3D, pos: Vector3, color: Color) -> void:
	_ball(parent, "WindowGlass", pos, Vector3(0.30, 0.30, 0.055), _material(BLUE, true))
	_ring(parent, "WindowFrame", pos + Vector3(0, 0, 0.015), 0.16, 0.028, _material(color), true)
	_rod(parent, "WindowMullion", pos + Vector3(0, -0.13, 0.04), pos + Vector3(0, 0.13, 0.04), 0.012, _material(CREAM))
	_ball(parent, "WindowGlint", pos + Vector3(-0.06, 0.055, 0.032), Vector3(0.062, 0.025, 0.012), _material(WHITE))


static func building(kind: int) -> Node3D:
	var variant := posmod(kind, 4)
	var root := _root(["HomeDome", "TownHall", "DecorShop", "ClothesShop"][variant])
	var accent: Color = [MINT, LILAC, PEACH, PINK][variant]
	var trim := _material(accent)
	var cream := _material(CREAM)
	# A buried skirt meets the curved ground at the foundation's outer edge.
	# Preserve the existing top height and doorway threshold.
	_tube(root, "Foundation", Vector3(0, 0.02, 0), 0.96, 0.32, _material(TEAL))
	_tube(root, "FoundationLip", Vector3(0, 0.19, 0), 0.94, 0.075, cream)
	if variant == 0:
		_ball(root, "Dome", Vector3(0, 0.55, 0), Vector3(1.80, 1.67, 1.65), cream)
		_ball(root, "RoofCap", Vector3(0, 1.15, -0.035), Vector3(1.65, 0.63, 1.54), trim)
		_tube(root, "Chimney", Vector3(-0.48, 1.50, -0.15), 0.11, 0.50, _material(PEACH))
		_ball(root, "ChimneyCap", Vector3(-0.48, 1.76, -0.15), Vector3(0.30, 0.12, 0.30), cream)
	else:
		_softbox(root, "Walls", Vector3(0, 0.78, 0), Vector3(1.64, 1.18, 1.37), 0.18, cream)
		_softbox(root, "Eaves", Vector3(0, 1.36, 0), Vector3(1.86, 0.14, 1.58), 0.06, trim)
		_ball(root, "PillowRoof", Vector3(0, 1.40, 0), Vector3(1.80, 0.57, 1.51), trim)
	# A layered capsule creates an arched doorway with a real protruding frame.
	_capsule(root, "DoorFrame", Vector3(0, 0.63, 0.72), 0.26, 0.90, trim)
	var door := _capsule(root, "Door", Vector3(0, 0.62, 0.785), 0.205, 0.76, _material(TEAL))
	door.scale.z = 0.33
	_ball(root, "DoorWindow", Vector3(0, 0.78, 0.855), Vector3(0.22, 0.22, 0.035), _material(GOLD, true, 0.15))
	_ball(root, "Doorknob", Vector3(0.125, 0.52, 0.86), Vector3.ONE * 0.052, _material(GOLD, true))
	_softbox(root, "WelcomeStep", Vector3(0, 0.12, 0.89), Vector3(0.65, 0.16, 0.36), 0.06, trim)
	for side in [-1.0, 1.0]:
		_window(root, Vector3(side * 0.54, 0.87, 0.683 if variant != 0 else 0.63), accent)
		_tube(root, "FlowerPot", Vector3(side * 0.67, 0.30, 0.70), 0.115, 0.23, trim, 0.145)
		_ball(root, "PotShrub", Vector3(side * 0.67, 0.48, 0.70), Vector3(0.31, 0.29, 0.29), _material(MINT))
	match variant:
		0:
			_star(root, Vector3(0, 1.38, 0.53), 0.11, _material(GOLD))
		1:
			_softbox(root, "ClockTower", Vector3(0, 1.65, -0.04), Vector3(0.49, 0.49, 0.43), 0.075, cream)
			_ball(root, "TowerRoof", Vector3(0, 1.91, -0.04), Vector3(0.63, 0.20, 0.57), trim)
			_ball(root, "ClockFace", Vector3(0, 1.69, 0.185), Vector3(0.30, 0.30, 0.035), _material(GOLD))
			_ring(root, "ClockRim", Vector3(0, 1.69, 0.20), 0.155, 0.018, _material(TEAL), true)
			_rod(root, "ClockHour", Vector3(0, 1.69, 0.22), Vector3(-0.065, 1.72, 0.22), 0.012, _material(INK))
			_rod(root, "ClockMinute", Vector3(0, 1.69, 0.22), Vector3(0, 1.79, 0.22), 0.010, _material(INK))
		2, 3:
			for i in range(7):
				var stripe_mat := cream if i % 2 == 0 else trim
				var x := (i - 3) * 0.22
				var awning := _softbox(root, "AwningStripe", Vector3(x, 1.20, 0.79), Vector3(0.222, 0.075, 0.45), 0.032, stripe_mat)
				awning.rotation.x = 0.18
				_ball(root, "Scallop", Vector3(x, 1.14, 1.0), Vector3(0.22, 0.15, 0.09), stripe_mat)
			_softbox(root, "Sign", Vector3(0, 1.72, 0.21), Vector3(0.67, 0.39, 0.12), 0.055, cream)
			if variant == 2:
				_star(root, Vector3(0, 1.73, 0.29), 0.155, _material(GOLD))
			else:
				var cloth := _material(LILAC)
				_softbox(root, "Shirt", Vector3(0, 1.71, 0.29), Vector3(0.16, 0.20, 0.035), 0.016, cloth)
				for side in [-1.0, 1.0]:
					_rod(root, "ShirtSleeve", Vector3(side * 0.055, 1.79, 0.29), Vector3(side * 0.135, 1.74, 0.29), 0.038, cloth)
				_ball(root, "ShirtCollar", Vector3(0, 1.81, 0.313), Vector3(0.066, 0.042, 0.015), cream)
	return root


static func tree(style: int) -> Node3D:
	var variant := posmod(style, 4)
	var root := _root(["CloudTree", "CandyPine", "PeachTree", "MoonWillow"][variant])
	var bark := _material(SOIL)
	_tube(root, "RootFlare", Vector3(0, 0.09, 0), 0.18, 0.18, bark, 0.09)
	_capsule(root, "Trunk", Vector3(0, 0.58, 0), 0.085, 1.12, bark)
	for side in [-1.0, 1.0]:
		_rod(root, "Branch", Vector3(0, 0.64, 0), Vector3(side * 0.27, 1.03, 0), 0.045, bark)
	match variant:
		0:
			var leaves := _material(MINT)
			_ball(root, "Crown", Vector3(0, 1.40, 0), Vector3(0.83, 0.86, 0.76), leaves)
			_ball(root, "LeftCloud", Vector3(-0.32, 1.18, 0), Vector3(0.67, 0.63, 0.66), leaves)
			_ball(root, "RightCloud", Vector3(0.33, 1.25, 0.02), Vector3(0.65, 0.67, 0.67), _material(BLUE))
		1:
			for i in range(3):
				var width := 0.98 - float(i) * 0.22
				_ball(root, "PineTier", Vector3(0, 0.90 + i * 0.30, 0), Vector3(width, 0.65, width), _material([TEAL, MINT, BLUE][i]))
			_star(root, Vector3(0, 1.91, 0), 0.13, _material(GOLD))
		2:
			_ball(root, "Crown", Vector3(0, 1.25, 0), Vector3(1.13, 1.03, 0.92), _material(PINK))
			_ball(root, "TopTuft", Vector3(-0.18, 1.65, -0.04), Vector3(0.58, 0.45, 0.54), _material(PEACH))
			for i in range(5):
				var angle := float(i) * 2.39996
				_ball(root, "Fruit", Vector3(sin(angle) * 0.37, 1.25 + cos(angle) * 0.29, 0.38), Vector3.ONE * 0.14, _material(GOLD))
		3:
			_ball(root, "Canopy", Vector3(0, 1.48, 0), Vector3(1.13, 0.58, 0.95), _material(LILAC))
			for i in range(7):
				var angle := TAU * float(i) / 7.0
				var pos := Vector3(cos(angle) * 0.40, 1.18, sin(angle) * 0.33)
				_ball(root, "DroopingLeaf", pos, Vector3(0.24, 0.68 + float(i % 2) * 0.16, 0.25), _material(PINK if i % 2 == 0 else LILAC))
			_ball(root, "MoonPearl", Vector3(0, 1.85, 0), Vector3.ONE * 0.18, _material(GOLD, false, 0.2))
	return root


# New catalog miniatures use their own economical meshes. Legacy art above is frozen.
static func _decor_ball(parent: Node3D, label: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 16
	shape.rings = 8
	var node := _mesh(parent, label, shape, pos, mat)
	node.scale = size
	return node


# One rounded cuboid surface, instead of overlapping boxes, corners and edges.
static func _decor_box(parent: Node3D, label: String, pos: Vector3, size: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var source := BoxMesh.new()
	source.size = Vector3.ONE * 2.0
	source.subdivide_width = 4
	source.subdivide_height = 4
	source.subdivide_depth = 4
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var half := size * 0.5
	var r := clampf(radius, 0.001, minf(half.x, minf(half.y, half.z)) * 0.98)
	var core := half - Vector3.ONE * r
	for i in range(vertices.size()):
		var point := Vector3.ZERO
		for axis in range(3):
			var stops := [-half[axis], -half[axis] + r * 0.293, -core[axis], core[axis], half[axis] - r * 0.293, half[axis]]
			point[axis] = stops[clampi(roundi((vertices[i][axis] + 1.0) * 2.5), 0, 5)]
		var nearest := point.clamp(-core, core)
		var normal := (point - nearest).normalized()
		vertices[i] = nearest + normal * r
		normals[i] = normal
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var shape := ArrayMesh.new()
	shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _mesh(parent, label, shape, pos, mat)


static func _decor_tube(parent: Node3D, label: String, pos: Vector3, radius: float, height: float, mat: Material, top: float = -1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0.0 else top
	shape.height = height
	shape.radial_segments = 20
	return _mesh(parent, label, shape, pos, mat)


static func _decor_ring(parent: Node3D, label: String, pos: Vector3, radius: float, thickness: float, mat: Material, front: bool = false) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = radius - thickness
	shape.outer_radius = radius + thickness
	shape.rings = 24
	shape.ring_segments = 8
	var node := _mesh(parent, label, shape, pos, mat)
	if front:
		node.rotation.x = PI * 0.5
	return node


# A capped eight-sided tube follows the whole curve in one mesh, with smooth normals.
static func _decor_curve(parent: Node3D, label: String, points: PackedVector3Array, radius: float, mat: Material) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in range(points.size()):
		var tangent := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var reference := Vector3.FORWARD if absf(tangent.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
		var u := tangent.cross(reference).normalized()
		var v := tangent.cross(u).normalized()
		for j in range(8):
			var angle := TAU * float(j) / 8.0
			var normal := u * cos(angle) + v * sin(angle)
			vertices.append(points[i] + radius * normal)
			normals.append(normal)
			if i < points.size() - 1:
				var a := i * 8 + j
				var b := i * 8 + (j + 1) % 8
				indices.append_array(PackedInt32Array([a, a + 8, b, b, a + 8, b + 8]))
	for end in [0, points.size() - 1]:
		var outward := (points[0] - points[1]).normalized() if end == 0 else (points[end] - points[end - 1]).normalized()
		var center := vertices.size()
		vertices.append(points[end])
		normals.append(outward)
		for j in range(8):
			vertices.append(vertices[end * 8 + j])
			normals.append(outward)
		for j in range(8):
			var a := center + 1 + j
			var b := center + 1 + (j + 1) % 8
			indices.append_array(PackedInt32Array([center, a, b] if end == 0 else [center, b, a]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var shape := ArrayMesh.new()
	shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _mesh(parent, label, shape, Vector3.ZERO, mat)


static func _decor_arc(parent: Node3D, label: String, center: Vector3, radii: Vector2, start: float, end: float, thickness: float, mat: Material, horizontal: bool = false) -> MeshInstance3D:
	var points := PackedVector3Array()
	var steps := maxi(8, ceili(absf(end - start) * 8.0))
	for i in range(steps + 1):
		var angle := lerpf(start, end, float(i) / float(steps))
		var offset := Vector3(cos(angle) * radii.x, sin(angle) * radii.y, 0)
		if horizontal:
			offset = Vector3(offset.x, 0, offset.y)
		points.append(center + offset)
	return _decor_curve(parent, label, points, thickness, mat)


static func _decor_stem(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	return _decor_curve(parent, label, PackedVector3Array([a, b]), radius, mat)


static func _decor_leaf(parent: Node3D, pos: Vector3, size: float, angle: float, mat: Material) -> void:
	_decor_ball(parent, "SatinLeaf", pos, Vector3(size * 0.48, size, size * 0.22), mat).rotation.z = angle


static func _decor_book(parent: Node3D, pos: Vector3, scale_factor: float, cover: Material, paper: Material, ink: Material, ribbon: Material) -> void:
	var book := _pivot(parent, "OpenBook", pos)
	book.scale = Vector3.ONE * scale_factor
	book.rotation = Vector3(-0.12, -0.18, 0)
	for side in [-1.0, 1.0]:
		var page := _pivot(book, "LeftPage" if side < 0 else "RightPage", Vector3.ZERO)
		page.rotation.z = side * 0.10
		_decor_box(page, "ClothCover", Vector3(side * 0.095, 0, 0), Vector3(0.20, 0.028, 0.255), 0.012, cover)
		_decor_box(page, "PageBlock", Vector3(side * 0.095, 0.026, 0), Vector3(0.178, 0.036, 0.230), 0.008, paper)
		for line in range(4):
			_decor_stem(page, "PrintedLine", Vector3(side * 0.035, 0.046, -0.063 + line * 0.038), Vector3(side * (0.155 if line < 3 else 0.12), 0.046, -0.063 + line * 0.038), 0.003, ink)
	_decor_stem(book, "Binding", Vector3(0, 0.028, -0.13), Vector3(0, 0.028, 0.13), 0.012, cover)
	_decor_curve(book, "RibbonBookmark", PackedVector3Array([Vector3(0.035, 0.05, 0.02), Vector3(0.035, 0.05, 0.12), Vector3(0.035, 0.01, 0.16), Vector3(0.035, -0.026, 0.17)]), 0.008, ribbon)


static func _decor_cup(parent: Node3D, pos: Vector3, size: float, ceramic: Material, rim: Material, tea: Material) -> void:
	var cup := _pivot(parent, "Teacup", pos)
	cup.scale = Vector3.ONE * size
	_decor_ball(cup, "Saucer", Vector3(0, 0.022, 0), Vector3(0.29, 0.044, 0.29), rim)
	_decor_tube(cup, "PorcelainCup", Vector3(0, 0.09, 0), 0.068, 0.13, ceramic, 0.095)
	_decor_ring(cup, "DrinkingRim", Vector3(0, 0.158, 0), 0.088, 0.012, rim)
	_decor_tube(cup, "TeaSurface", Vector3(0, 0.151, 0), 0.078, 0.008, tea)
	_decor_ring(cup, "LoopHandle", Vector3(0.106, 0.099, 0), 0.049, 0.012, ceramic, true)


# Measure actual transformed vertices once at creation. Only the new model group is
# adjusted: root transforms stay clean for placement, and the catalog owns spacing.
static func _decor_bounds(node: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> Vector3:
	var space := transform * node.transform
	var bounds := Vector3(INF, -INF, 0)
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var vertices: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point: Vector3 = space * vertex
				bounds.x = minf(bounds.x, point.y)
				bounds.y = maxf(bounds.y, point.y)
				bounds.z = maxf(bounds.z, Vector2(point.x, point.z).length())
	for child in node.get_children():
		if child is Node3D:
			var child_bounds := _decor_bounds(child, space)
			bounds.x = minf(bounds.x, child_bounds.x)
			bounds.y = maxf(bounds.y, child_bounds.y)
			bounds.z = maxf(bounds.z, child_bounds.z)
	return bounds


static func _new_decoration(kind: int) -> Node3D:
	var catalog := preload("res://scripts/catalog.gd")
	var root := _root(catalog.NAMES[kind])
	var model := _pivot(root, "Miniature", Vector3.ZERO)
	var p := {"cream": _material(CREAM), "white": _material(WHITE), "mint": _material(MINT), "teal": _material(TEAL), "peach": _material(PEACH), "pink": _material(PINK), "lilac": _material(LILAC), "blue": _material(BLUE), "gold": _material(GOLD, true), "ink": _material(INK), "soil": _material(SOIL)}
	match kind:
		6: _reading_nook(model, p)
		7: _tea_table(model, p)
		8: _satellite_birdbath(model, p)
		9: _cloud_cushion(model, p)
		10: _meteor_mailbox(model, p)
		11: _solar_garden_arch(model, p)
		12: _moonberry_basket(model, p)
		13: _comet_lantern(model, p)
		14: _tiny_observatory(model, p)
		15: _robot_music_box(model, p)
		16: _stardust_picnic(model, p)
		17: _crystal_terrarium(model, p)
	var bounds := _decor_bounds(model)
	var footprint_scale: float = catalog.RADII[kind] * 0.98 / bounds.z
	model.scale = Vector3(footprint_scale, 1.0, footprint_scale)
	model.position.y = -bounds.x
	return root


static func _reading_nook(root: Node3D, p: Dictionary) -> void:
	# A scalloped rug anchors a low armchair, with a book open on a lap cushion.
	_decor_ball(root, "WovenOvalRug", Vector3(0, 0.025, 0.03), Vector3(1.64, 0.05, 1.32), p.lilac)
	_decor_ring(root, "RugCreamBinding", Vector3(0, 0.037, 0.03), 0.73, 0.019, p.cream).scale.z = 0.79
	for x in [-0.32, 0.32]:
		for z in [-0.27, 0.30]:
			_decor_tube(root, "TurnedChairFoot", Vector3(x, 0.13, z), 0.049, 0.22, p.teal, 0.036)
	_decor_box(root, "ChairFrame", Vector3(0, 0.285, 0), Vector3(0.90, 0.17, 0.82), 0.074, p.cream)
	_decor_box(root, "UpholsteredSeat", Vector3(0, 0.42, 0.02), Vector3(0.70, 0.20, 0.66), 0.095, p.peach)
	_decor_box(root, "HighCurvedBack", Vector3(0, 0.80, -0.31), Vector3(0.83, 0.87, 0.20), 0.095, p.cream).rotation.x = -0.10
	_decor_box(root, "BackCushion", Vector3(0, 0.81, -0.198), Vector3(0.65, 0.65, 0.15), 0.073, p.peach).rotation.x = -0.10
	for side in [-1.0, 1.0]:
		_decor_box(root, "PaddedArm", Vector3(side * 0.395, 0.55, 0.015), Vector3(0.18, 0.26, 0.70), 0.088, p.cream)
		_decor_ball(root, "BackTuft", Vector3(side * 0.14, 0.88, -0.105), Vector3(0.036, 0.036, 0.014), p.gold)
	var cushion := _decor_box(root, "SageLapCushion", Vector3(0.015, 0.565, 0.12), Vector3(0.47, 0.16, 0.40), 0.076, p.mint)
	cushion.rotation.y = -0.16
	_decor_book(root, Vector3(0.015, 0.66, 0.14), 0.93, p.lilac, p.cream, p.soil, p.gold)
	# A folded blanket drapes over the right arm; a tiny tassel finishes each stripe.
	_decor_box(root, "FoldedThrowTop", Vector3(0.395, 0.69, 0.08), Vector3(0.23, 0.045, 0.34), 0.02, p.blue)
	_decor_box(root, "DrapedThrow", Vector3(0.503, 0.51, 0.08), Vector3(0.044, 0.37, 0.34), 0.02, p.blue)
	for z in [-0.045, 0.035, 0.115, 0.195]:
		_decor_stem(root, "BlanketStitch", Vector3(0.527, 0.36, z), Vector3(0.527, 0.65, z), 0.005, p.cream)
		_decor_stem(root, "BlanketTassel", Vector3(0.502, 0.33, z), Vector3(0.513, 0.28, z), 0.008, p.cream)


static func _tea_table(root: Node3D, p: Dictionary) -> void:
	# A flying-saucer tea service with three splayed legs and two different cups.
	for i in range(3):
		var a := TAU * float(i) / 3.0 + PI * 0.5
		var foot := Vector3(cos(a) * 0.37, 0.039, sin(a) * 0.37)
		_decor_ball(root, "BrassFoot", foot, Vector3(0.12, 0.078, 0.12), p.gold)
		_decor_stem(root, "SplayedLeg", foot + Vector3(0, 0.02, 0), Vector3(cos(a) * 0.22, 0.53, sin(a) * 0.22), 0.036, p.teal)
	_decor_ball(root, "SaucerTableEdge", Vector3(0, 0.57, 0), Vector3(1.24, 0.17, 1.24), p.peach)
	_decor_tube(root, "CreamTabletop", Vector3(0, 0.616, 0), 0.57, 0.07, p.cream)
	_decor_ring(root, "OrbitInlay", Vector3(0, 0.654, 0), 0.48, 0.008, p.gold)
	_decor_cup(root, Vector3(-0.29, 0.655, 0.15), 0.86, p.mint, p.cream, p.soil)
	var second := _pivot(root, "GuestPlaceSetting", Vector3(0.27, 0.655, 0.12))
	second.rotation.y = PI
	_decor_cup(second, Vector3.ZERO, 0.86, p.lilac, p.cream, p.soil)
	var pot := _pivot(root, "MoonTeapot", Vector3(0.035, 0.655, -0.19))
	_decor_ball(pot, "PotBelly", Vector3(0, 0.14, 0), Vector3(0.31, 0.28, 0.28), p.blue)
	_decor_ring(pot, "PotHandle", Vector3(-0.173, 0.16, 0), 0.089, 0.021, p.blue, true)
	_decor_curve(pot, "PouringSpout", PackedVector3Array([Vector3(0.10, 0.11, 0), Vector3(0.18, 0.13, 0), Vector3(0.23, 0.22, 0), Vector3(0.26, 0.24, 0)]), 0.029, p.blue)
	_decor_ball(pot, "SpoutOpening", Vector3(0.271, 0.249, 0), Vector3(0.014, 0.020, 0.037), p.ink).rotation.z = -0.6
	_decor_ball(pot, "Lid", Vector3(0, 0.275, 0), Vector3(0.19, 0.049, 0.18), p.cream)
	_decor_ball(pot, "LidPearl", Vector3(0, 0.319, 0), Vector3.ONE * 0.057, p.gold)
	_decor_ball(root, "BiscuitPlate", Vector3(0, 0.673, 0.31), Vector3(0.26, 0.032, 0.21), p.blue)
	for x in [-0.054, 0.054]:
		_decor_tube(root, "MoonBiscuit", Vector3(x, 0.703, 0.31), 0.047, 0.034, p.gold)
		for z in [-0.015, 0.015]:
			_decor_ball(root, "BiscuitDimple", Vector3(x, 0.721, 0.31 + z), Vector3.ONE * 0.008, p.soil)


static func _satellite_birdbath(root: Node3D, p: Dictionary) -> void:
	_decor_ball(root, "PedestalFoot", Vector3(0, 0.065, 0), Vector3(0.53, 0.13, 0.53), p.mint)
	_decor_tube(root, "FlaredPedestal", Vector3(0, 0.365, 0), 0.15, 0.59, p.cream, 0.09)
	_decor_ring(root, "PedestalCollar", Vector3(0, 0.55, 0), 0.103, 0.018, p.gold)
	_decor_ball(root, "SatelliteDish", Vector3(0, 0.66, 0), Vector3(0.94, 0.25, 0.94), p.cream)
	_decor_tube(root, "BlueWater", Vector3(0, 0.734, 0), 0.425, 0.021, _material(BLUE, true))
	_decor_ring(root, "DishRim", Vector3(0, 0.753, 0), 0.445, 0.025, p.mint)
	_decor_ring(root, "FirstRipple", Vector3(-0.06, 0.748, 0.055), 0.10, 0.004, p.cream)
	_decor_ring(root, "SecondRipple", Vector3(-0.06, 0.748, 0.055), 0.18, 0.004, p.cream)
	_decor_stem(root, "ReceiverArm", Vector3(-0.27, 0.70, -0.26), Vector3(-0.19, 1.00, -0.13), 0.016, p.gold)
	_decor_ball(root, "ReceiverPearl", Vector3(-0.19, 1.00, -0.13), Vector3.ONE * 0.074, p.peach)
	var bird := _pivot(root, "VisitingSpaceBird", Vector3(0.27, 0.775, -0.15))
	for side in [-1.0, 1.0]:
		_decor_stem(bird, "BirdLeg", Vector3(side * 0.037, 0, 0), Vector3(side * 0.037, 0.092, 0), 0.011, p.gold)
		_decor_stem(bird, "BirdToe", Vector3(side * 0.037, 0.008, -0.025), Vector3(side * 0.037, 0.008, 0.038), 0.011, p.gold)
	_decor_ball(bird, "RoundBirdBody", Vector3(0, 0.17, 0), Vector3(0.22, 0.24, 0.24), p.peach)
	_decor_ball(bird, "CreamBreast", Vector3(0, 0.155, 0.097), Vector3(0.15, 0.16, 0.05), p.cream)
	_decor_ball(bird, "BirdHead", Vector3(0, 0.295, 0.04), Vector3(0.18, 0.18, 0.18), p.peach)
	for side in [-1.0, 1.0]:
		_decor_ball(bird, "Wing", Vector3(side * 0.098, 0.18, -0.01), Vector3(0.05, 0.14, 0.15), p.lilac).rotation.x = -0.25
		_decor_ball(bird, "BirdEye", Vector3(side * 0.054, 0.311, 0.111), Vector3.ONE * 0.020, p.ink)
	_decor_ball(bird, "Beak", Vector3(0, 0.281, 0.142), Vector3(0.055, 0.037, 0.075), p.gold)
	_decor_ball(bird, "TailFeather", Vector3(0, 0.18, -0.142), Vector3(0.10, 0.045, 0.19), p.lilac).rotation.x = 0.35
	_decor_leaf(bird, Vector3(-0.018, 0.403, 0.015), 0.11, -0.30, p.mint)


static func _cloud_cushion(root: Node3D, p: Dictionary) -> void:
	# A squat upholstered cloud: lower piping, tuft buttons and a stitched patch.
	_decor_ball(root, "FlatCushionUnderside", Vector3(0, 0.052, 0), Vector3(0.87, 0.104, 0.68), p.lilac)
	_decor_ball(root, "CloudMiddle", Vector3(0, 0.225, 0), Vector3(0.68, 0.43, 0.65), p.cream)
	_decor_ball(root, "CloudLeftPuff", Vector3(-0.29, 0.185, 0.015), Vector3(0.41, 0.31, 0.55), p.cream)
	_decor_ball(root, "CloudRightPuff", Vector3(0.30, 0.19, -0.025), Vector3(0.39, 0.33, 0.56), p.cream)
	_decor_ball(root, "CloudFrontPuff", Vector3(0.07, 0.15, 0.20), Vector3(0.48, 0.27, 0.35), p.cream)
	_decor_arc(root, "LavenderPiping", Vector3(0, 0.107, 0), Vector2(0.43, 0.32), 0, TAU, 0.012, p.lilac, true)
	for x in [-0.13, 0.13]:
		_decor_ball(root, "QuiltedDimple", Vector3(x, 0.418, -0.015), Vector3(0.035, 0.011, 0.035), p.lilac)
	var patch := _decor_box(root, "SmallMoonPatch", Vector3(0.24, 0.23, 0.269), Vector3(0.15, 0.105, 0.021), 0.010, p.blue)
	patch.rotation.z = 0.18
	_decor_arc(root, "EmbroideredMoon", Vector3(0.245, 0.233, 0.288), Vector2(0.025, 0.029), 0.70, TAU - 0.70, 0.008, p.gold)
	for x in [0.19, 0.29]:
		_decor_stem(root, "PatchStitch", Vector3(x, 0.20, 0.288), Vector3(x + 0.005, 0.214, 0.288), 0.003, p.cream)
	_decor_box(root, "FabricLabel", Vector3(-0.347, 0.10, 0.20), Vector3(0.09, 0.017, 0.071), 0.007, p.peach).rotation.y = -0.4


static func _meteor_mailbox(root: Node3D, p: Dictionary) -> void:
	_decor_ball(root, "MeteorStoneFoot", Vector3(0, 0.073, 0), Vector3(0.65, 0.146, 0.53), p.lilac)
	for pos in [Vector3(-0.18, 0.117, 0.11), Vector3(0.15, 0.119, 0.07)]:
		_decor_ball(root, "StoneCrater", pos, Vector3(0.075, 0.015, 0.055), p.blue)
	_decor_tube(root, "LetterPost", Vector3(0, 0.40, 0), 0.061, 0.63, p.teal)
	_decor_ring(root, "PostCollar", Vector3(0, 0.62, 0), 0.068, 0.015, p.gold)
	_decor_box(root, "RoundedMailboxShell", Vector3(0, 0.91, 0), Vector3(0.51, 0.44, 0.67), 0.17, p.peach)
	_decor_box(root, "CreamFrontDoor", Vector3(0, 0.901, 0.331), Vector3(0.425, 0.362, 0.055), 0.027, p.cream)
	_decor_box(root, "LetterSlot", Vector3(0, 0.961, 0.362), Vector3(0.265, 0.039, 0.018), 0.008, p.ink)
	var letter := _pivot(root, "LetterPeekingOut", Vector3(-0.02, 0.956, 0.408))
	letter.rotation.x = 0.55
	_decor_box(letter, "Envelope", Vector3.ZERO, Vector3(0.194, 0.095, 0.010), 0.004, p.white)
	_decor_curve(letter, "EnvelopeFlap", PackedVector3Array([Vector3(-0.087, 0.038, 0.008), Vector3(0, -0.012, 0.008), Vector3(0.087, 0.038, 0.008)]), 0.003, p.blue)
	_decor_box(letter, "PostageStamp", Vector3(0.063, 0.018, 0.009), Vector3(0.027, 0.031, 0.004), 0.002, p.pink)
	_decor_ball(root, "DoorPull", Vector3(0, 0.801, 0.374), Vector3(0.11, 0.031, 0.041), p.gold)
	_decor_stem(root, "FlagMast", Vector3(0.268, 0.84, -0.05), Vector3(0.268, 1.31, -0.05), 0.016, p.gold)
	_decor_box(root, "RaisedMailFlag", Vector3(0.34, 1.245, -0.05), Vector3(0.15, 0.12, 0.027), 0.013, p.mint)
	_decor_ball(root, "FlagPivot", Vector3(0.274, 0.85, -0.024), Vector3.ONE * 0.052, p.cream)
	# Swept inlaid trails turn the mailbox body into a little pastel meteor.
	for y in [0.84, 0.94, 1.025]:
		_decor_curve(root, "MeteorTrail", PackedVector3Array([Vector3(-0.253, y, -0.12), Vector3(-0.26, y, 0.04), Vector3(-0.251, y + 0.025, 0.19)]), 0.009, p.gold)


static func _solar_garden_arch(root: Node3D, p: Dictionary) -> void:
	# Two planted feet carry an open arch; the sun is its keystone, not a solid gate.
	for side in [-1.0, 1.0]:
		_decor_box(root, "PlanterFoot", Vector3(side * 0.70, 0.105, 0), Vector3(0.35, 0.21, 0.42), 0.072, p.peach)
		_decor_box(root, "PlanterSoil", Vector3(side * 0.70, 0.208, 0), Vector3(0.28, 0.025, 0.34), 0.012, p.soil)
		_decor_stem(root, "IvoryUpright", Vector3(side * 0.66, 0.20, 0), Vector3(side * 0.66, 1.14, 0), 0.047, p.cream)
		_decor_stem(root, "RearUpright", Vector3(side * 0.66, 0.20, -0.18), Vector3(side * 0.66, 1.14, -0.18), 0.032, p.teal)
		for y in [0.42, 0.69, 0.96]:
			_decor_stem(root, "TrellisRung", Vector3(side * 0.66, y, -0.18), Vector3(side * 0.66, y, 0.035), 0.018, p.cream)
		var vine := PackedVector3Array()
		for i in range(15):
			var t := float(i) / 14.0
			vine.append(Vector3(side * 0.66 + sin(t * TAU * 1.6) * 0.08, 0.24 + t * 1.0, cos(t * TAU * 1.6) * 0.065))
		_decor_curve(root, "ClimbingVine", vine, 0.013, p.teal)
		for i in range(5):
			var pos := Vector3(side * 0.66 + (0.075 if i % 2 == 0 else -0.075), 0.35 + i * 0.18, 0.075)
			_decor_leaf(root, pos, 0.18, -side * (0.65 if i % 2 == 0 else -0.65), p.mint)
			if i % 2 == 0:
				_decor_ball(root, "Moonbud", pos + Vector3(side * 0.038, 0.045, 0.038), Vector3.ONE * 0.068, p.pink)
	_decor_arc(root, "CreamArch", Vector3(0, 1.14, 0), Vector2(0.66, 0.53), 0, PI, 0.047, p.cream)
	_decor_arc(root, "RearArch", Vector3(0, 1.14, -0.18), Vector2(0.66, 0.53), 0, PI, 0.032, p.teal)
	for angle in [0.35, 0.85, 1.57, 2.29, 2.79]:
		_decor_stem(root, "ArchCrossTie", Vector3(cos(angle) * 0.66, 1.14 + sin(angle) * 0.53, -0.18), Vector3(cos(angle) * 0.66, 1.14 + sin(angle) * 0.53, 0), 0.02, p.gold)
	_decor_ball(root, "SunMedallion", Vector3(0, 1.72, 0.045), Vector3(0.24, 0.24, 0.06), p.gold)
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var direction := Vector3(cos(angle), sin(angle), 0)
		_decor_stem(root, "SunRay", Vector3(0, 1.72, 0.045) + direction * 0.143, Vector3(0, 1.72, 0.045) + direction * 0.184, 0.014, p.gold)
	_decor_arc(root, "SunSmile", Vector3(0, 1.715, 0.079), Vector2(0.045, 0.035), PI + 0.3, TAU - 0.3, 0.005, p.soil)
	for x in [-0.041, 0.041]:
		_decor_ball(root, "SunEye", Vector3(x, 1.751, 0.076), Vector3.ONE * 0.011, p.soil)


static func _moonberry_basket(root: Node3D, p: Dictionary) -> void:
	_decor_ball(root, "BasketFoot", Vector3(0, 0.045, 0), Vector3(0.54, 0.09, 0.43), p.gold)
	_decor_tube(root, "WovenBasket", Vector3(0, 0.205, 0), 0.265, 0.32, p.gold, 0.37).scale.z = 0.79
	_decor_ball(root, "LinenLining", Vector3(0, 0.358, 0), Vector3(0.69, 0.075, 0.54), p.cream)
	_decor_ring(root, "RolledBasketRim", Vector3(0, 0.366, 0), 0.359, 0.025, p.peach).scale.z = 0.79
	for y in [0.12, 0.185, 0.25, 0.313]:
		var radius: float = 0.265 + (y - 0.045) / 0.32 * 0.105
		_decor_ring(root, "HorizontalWeave", Vector3(0, y, 0), radius, 0.009, p.cream).scale.z = 0.79
	for i in range(14):
		var angle := TAU * float(i) / 14.0
		_decor_stem(root, "BasketReed", Vector3(cos(angle) * 0.272, 0.08, sin(angle) * 0.272 * 0.79), Vector3(cos(angle) * 0.354, 0.34, sin(angle) * 0.354 * 0.79), 0.009, p.peach)
	_decor_arc(root, "BentWickerHandle", Vector3(0, 0.34, -0.035), Vector2(0.355, 0.45), 0, PI, 0.024, p.gold)
	_decor_arc(root, "HandleGrip", Vector3(0, 0.34, -0.035), Vector2(0.355, 0.45), 1.25, 1.89, 0.029, p.cream)
	for i in range(7):
		var angle := TAU * float(i) / 6.0
		var center := Vector3(cos(angle) * 0.215, 0.419, sin(angle) * 0.157) if i < 6 else Vector3(0, 0.475, 0)
		var color: Material = p.lilac if i % 2 == 0 else p.blue
		_decor_ball(root, "Moonberry", center, Vector3(0.195, 0.19, 0.19), color)
		_decor_ball(root, "BerryBlush", center + Vector3(-0.036, 0.045, 0.063), Vector3(0.041, 0.023, 0.018), p.pink)
		_decor_stem(root, "BerryStem", center + Vector3(0, 0.076, 0), center + Vector3(0.006, 0.116, 0), 0.008, p.teal)
		_decor_leaf(root, center + Vector3(0.027, 0.109, 0), 0.074, -0.85, p.mint)
	var cloth := _decor_box(root, "LinenNapkinCorner", Vector3(0.105, 0.277, 0.292), Vector3(0.20, 0.23, 0.025), 0.012, p.cream)
	cloth.rotation.z = -0.16
	_decor_arc(root, "NapkinCrescent", Vector3(0.107, 0.265, 0.311), Vector2(0.025, 0.033), 0.65, TAU - 0.65, 0.007, p.lilac)


static func _comet_lantern(root: Node3D, p: Dictionary) -> void:
	# A portable cage lantern with a comet suspended inside warm translucent glass.
	_decor_ball(root, "WeightedLanternFoot", Vector3(0, 0.055, 0), Vector3(0.69, 0.11, 0.63), p.teal)
	_decor_tube(root, "LowerLanternCollar", Vector3(0, 0.142, 0), 0.263, 0.10, p.cream)
	_decor_ring(root, "BaseBrassTrim", Vector3(0, 0.195, 0), 0.252, 0.017, p.gold)
	var glass := _material(Color(0.94, 0.83, 0.60, 0.16), true)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_decor_ball(root, "AmberGlassChamber", Vector3(0, 0.466, 0), Vector3(0.47, 0.60, 0.43), glass)
	var light := _material(GOLD, false, 0.65)
	_decor_ball(root, "CometHead", Vector3(-0.054, 0.378, 0.028), Vector3.ONE * 0.16, light)
	_decor_curve(root, "CometTail", PackedVector3Array([Vector3(-0.02, 0.408, 0.02), Vector3(0.065, 0.49, 0.02), Vector3(0.08, 0.58, 0.02), Vector3(0.045, 0.65, 0.02)]), 0.029, light)
	_decor_curve(root, "SecondCometTail", PackedVector3Array([Vector3(-0.072, 0.424, 0.02), Vector3(-0.034, 0.53, 0.02), Vector3(-0.055, 0.62, 0.02)]), 0.013, p.cream)
	_decor_stem(root, "CometSuspension", Vector3(0.045, 0.65, 0.02), Vector3(0.045, 0.74, 0.02), 0.004, p.gold)
	for i in range(4):
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var x := cos(angle) * 0.236
		var z := sin(angle) * 0.218
		_decor_curve(root, "ProtectiveCageRib", PackedVector3Array([Vector3(x * 0.85, 0.18, z * 0.85), Vector3(x, 0.30, z), Vector3(x, 0.60, z), Vector3(x * 0.85, 0.745, z * 0.85)]), 0.018, p.cream)
	_decor_ball(root, "ScallopedLanternRoof", Vector3(0, 0.754, 0), Vector3(0.58, 0.15, 0.54), p.peach)
	_decor_tube(root, "RoofVent", Vector3(0, 0.844, 0), 0.089, 0.075, p.teal)
	_decor_ball(root, "VentCap", Vector3(0, 0.89, 0), Vector3(0.24, 0.06, 0.22), p.cream)
	_decor_arc(root, "CarryingHandle", Vector3(0, 0.81, 0), Vector2(0.22, 0.35), 0, PI, 0.02, p.gold)
	_decor_arc(root, "InsulatedHandleGrip", Vector3(0, 0.81, 0), Vector2(0.22, 0.35), 1.19, 1.95, 0.029, p.teal)
	_decor_ball(root, "DimmerKnob", Vector3(0, 0.14, 0.274), Vector3(0.065, 0.065, 0.035), p.gold)


static func _tiny_observatory(root: Node3D, p: Dictionary) -> void:
	# The open roof slit and projecting telescope distinguish it from a house dome.
	_decor_tube(root, "RoundFoundation", Vector3(0, 0.07, 0), 0.61, 0.14, p.teal)
	_decor_ring(root, "FoundationBead", Vector3(0, 0.13, 0), 0.58, 0.028, p.cream)
	_decor_tube(root, "ObservatoryDrum", Vector3(0, 0.465, 0), 0.51, 0.65, p.cream)
	_decor_ring(root, "DomeRotationTrack", Vector3(0, 0.78, 0), 0.522, 0.027, p.gold)
	# Build two hemispherical shells with a real longitudinal opening between them.
	for side in [-1.0, 1.0]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var cols := 12
		var rows := 8
		for row in range(rows):
			for col in range(cols):
				var corners := PackedVector3Array()
				for corner in [Vector2(col, row), Vector2(col + 1, row), Vector2(col, row + 1), Vector2(col + 1, row + 1)]:
					var elevation := float(corner.y) / float(rows) * PI * 0.5
					var azimuth := 0.20 + float(corner.x) / float(cols) * (PI - 0.40)
					corners.append(Vector3(side * sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation)))
				var order := [0, 2, 1, 1, 2, 3] if side > 0 else [0, 1, 2, 1, 3, 2]
				for index in range(order.size()):
					# The top row contains one triangle per sector, avoiding collapsed poles.
					if row == rows - 1 and index >= 3:
						continue
					var normal: Vector3 = corners[order[index]]
					surface.set_normal(normal)
					surface.add_vertex(Vector3(normal.x * 0.545, 0.79 + normal.y * 0.51, normal.z * 0.545))
		var shell_mat: StandardMaterial3D = _material(LILAC)
		shell_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh(root, "LeftRoofShell" if side < 0 else "RightRoofShell", surface.commit(), Vector3.ZERO, shell_mat)
		var rim := PackedVector3Array()
		for i in range(17):
			var angle := PI * float(i) / 16.0
			rim.append(Vector3(side * 0.108 * absf(cos(angle)), 0.79 + sin(angle) * 0.51, cos(angle) * 0.534))
		_decor_curve(root, "SlitEdge", rim, 0.018, p.cream)
	_decor_stem(root, "TelescopeStand", Vector3(0, 0.68, 0), Vector3(0, 1.025, 0), 0.035, p.teal)
	var telescope := _pivot(root, "SkyTelescope", Vector3(0, 1.04, 0.15))
	telescope.rotation.x = 1.02
	_decor_tube(telescope, "OpticalBarrel", Vector3(0, 0.12, 0), 0.083, 0.52, p.cream)
	_decor_tube(telescope, "LensHood", Vector3(0, 0.385, 0), 0.106, 0.09, p.peach)
	_decor_tube(telescope, "DarkLens", Vector3(0, 0.433, 0), 0.088, 0.008, _material(INK, true))
	_decor_ring(telescope, "LensRim", Vector3(0, 0.439, 0), 0.091, 0.009, p.gold)
	_decor_ball(telescope, "OpticalGlint", Vector3(-0.024, 0.439, 0.022), Vector3(0.032, 0.008, 0.023), p.blue)
	_decor_box(root, "ArchedDoorFrame", Vector3(0, 0.385, 0.499), Vector3(0.27, 0.46, 0.066), 0.032, p.peach)
	_decor_box(root, "MintDoor", Vector3(0, 0.38, 0.538), Vector3(0.213, 0.396, 0.030), 0.014, p.teal)
	_decor_ring(root, "RoundDoorWindow", Vector3(0, 0.48, 0.561), 0.061, 0.013, p.gold, true)
	_decor_ball(root, "DoorWindowGlass", Vector3(0, 0.48, 0.557), Vector3(0.10, 0.10, 0.02), p.blue)
	_decor_ball(root, "DoorKnob", Vector3(0.068, 0.325, 0.564), Vector3.ONE * 0.028, p.gold)
	_decor_box(root, "FrontStep", Vector3(0, 0.064, 0.55), Vector3(0.37, 0.128, 0.26), 0.038, p.peach)
	for side in [-1.0, 1.0]:
		var window := _pivot(root, "SidePorthole", Vector3(side * 0.42, 0.50, 0.282))
		window.rotation.y = side * 0.98
		_decor_ball(window, "PortholeGlass", Vector3.ZERO, Vector3(0.15, 0.15, 0.026), p.blue)
		_decor_ring(window, "PortholeRim", Vector3(0, 0, 0.012), 0.083, 0.013, p.gold, true)


static func _robot_music_box(root: Node3D, p: Dictionary) -> void:
	# A wind-up cabinet with a tiny robot conductor on a visible record turntable.
	for x in [-0.29, 0.29]:
		for z in [-0.22, 0.22]:
			_decor_ball(root, "CabinetFoot", Vector3(x, 0.047, z), Vector3(0.11, 0.094, 0.11), p.gold)
	_decor_box(root, "MusicBoxCabinet", Vector3(0, 0.22, 0), Vector3(0.76, 0.33, 0.60), 0.083, p.blue)
	_decor_box(root, "CreamCabinetLip", Vector3(0, 0.385, 0), Vector3(0.79, 0.065, 0.63), 0.031, p.cream)
	_decor_box(root, "FrontSpeakerPanel", Vector3(-0.11, 0.224, 0.301), Vector3(0.39, 0.20, 0.028), 0.013, p.cream)
	for i in range(5):
		_decor_stem(root, "SpeakerSlot", Vector3(-0.255 + i * 0.071, 0.179, 0.321), Vector3(-0.255 + i * 0.071, 0.269, 0.321), 0.008, p.teal)
	_decor_ball(root, "VolumeDial", Vector3(0.225, 0.228, 0.322), Vector3(0.105, 0.105, 0.032), p.gold)
	_decor_stem(root, "DialPointer", Vector3(0.225, 0.229, 0.342), Vector3(0.243, 0.253, 0.342), 0.005, p.cream)
	_decor_tube(root, "RecordPlatter", Vector3(-0.04, 0.432, 0), 0.245, 0.034, p.teal)
	for radius in [0.14, 0.19, 0.225]:
		_decor_ring(root, "RecordGroove", Vector3(-0.04, 0.451, 0), radius, 0.003, p.blue)
	_decor_tube(root, "RecordLabel", Vector3(-0.04, 0.453, 0), 0.076, 0.008, p.peach)
	_decor_curve(root, "RecordTonearm", PackedVector3Array([Vector3(0.28, 0.43, -0.18), Vector3(0.28, 0.49, -0.18), Vector3(0.25, 0.49, 0.02), Vector3(0.15, 0.47, 0.12)]), 0.012, p.gold)
	var bot := _pivot(root, "ClockworkConductor", Vector3(-0.04, 0.46, 0))
	for side in [-1.0, 1.0]:
		_decor_ball(bot, "ToyShoe", Vector3(side * 0.066, 0.035, 0.02), Vector3(0.098, 0.07, 0.12), p.peach)
		_decor_stem(bot, "ToyLeg", Vector3(side * 0.066, 0.06, 0), Vector3(side * 0.066, 0.17, 0), 0.023, p.gold)
	_decor_box(bot, "ToyJacket", Vector3(0, 0.25, 0), Vector3(0.22, 0.24, 0.17), 0.049, p.mint)
	_decor_stem(bot, "ToyNeck", Vector3(0, 0.35, 0), Vector3(0, 0.405, 0), 0.024, p.gold)
	_decor_box(bot, "ToyHead", Vector3(0, 0.49, 0), Vector3(0.28, 0.23, 0.22), 0.065, p.cream)
	_decor_box(bot, "ToyFace", Vector3(0, 0.494, 0.11), Vector3(0.21, 0.13, 0.014), 0.006, p.teal)
	for x in [-0.052, 0.052]:
		_decor_ball(bot, "ToyEye", Vector3(x, 0.514, 0.125), Vector3(0.027, 0.041, 0.013), p.gold)
	_decor_arc(bot, "ToySmile", Vector3(0, 0.486, 0.124), Vector2(0.03, 0.02), PI, TAU, 0.004, p.cream)
	_decor_curve(bot, "RaisedConductorArm", PackedVector3Array([Vector3(-0.11, 0.32, 0), Vector3(-0.20, 0.36, 0), Vector3(-0.22, 0.46, 0.035)]), 0.026, p.mint)
	_decor_ball(bot, "ConductorHand", Vector3(-0.22, 0.46, 0.035), Vector3.ONE * 0.07, p.cream)
	_decor_stem(bot, "ConductorBaton", Vector3(-0.22, 0.47, 0.035), Vector3(-0.31, 0.68, 0.035), 0.008, p.gold)
	_decor_curve(bot, "OtherToyArm", PackedVector3Array([Vector3(0.11, 0.32, 0), Vector3(0.18, 0.27, 0), Vector3(0.19, 0.32, 0.065)]), 0.026, p.mint)
	_decor_ball(bot, "JacketButton", Vector3(0, 0.262, 0.091), Vector3.ONE * 0.034, p.gold)
	_decor_stem(bot, "ToyAntenna", Vector3(0.025, 0.60, 0), Vector3(0.04, 0.68, 0), 0.010, p.gold)
	_decor_ball(bot, "AntennaTip", Vector3(0.04, 0.69, 0), Vector3.ONE * 0.047, p.peach)
	_decor_stem(root, "WindingAxle", Vector3(0.36, 0.245, 0), Vector3(0.48, 0.245, 0), 0.021, p.gold)
	var key := _pivot(root, "ButterflyWindingKey", Vector3(0.48, 0.245, 0))
	key.rotation.y = PI * 0.5
	for side in [-1.0, 1.0]:
		_decor_ring(key, "KeyLoop", Vector3(side * 0.048, 0, 0), 0.043, 0.013, p.gold, true)


static func _stardust_picnic(root: Node3D, p: Dictionary) -> void:
	# A woven picnic spread with checks, thermos, star sandwiches and rolled blanket.
	_decor_box(root, "PicnicBlanket", Vector3(0, 0.026, 0), Vector3(1.40, 0.052, 1.16), 0.025, p.cream)
	for i in range(7):
		for j in range(6):
			if (i + j) % 2 == 0:
				_decor_box(root, "WovenGinghamSquare", Vector3(-0.60 + i * 0.20, 0.054, -0.48 + j * 0.192), Vector3(0.193, 0.009, 0.185), 0.004, p.peach)
	for side in [-1.0, 1.0]:
		for i in range(10):
			_decor_stem(root, "BlanketFringe", Vector3(-0.62 + i * 0.138, 0.027, side * 0.575), Vector3(-0.608 + i * 0.138, 0.026, side * 0.632), 0.009, p.cream)
	_decor_ball(root, "ServingPlatter", Vector3(-0.05, 0.085, 0.08), Vector3(0.61, 0.060, 0.42), p.mint)
	_decor_ring(root, "PlatterRim", Vector3(-0.05, 0.111, 0.08), 0.274, 0.012, p.cream).scale.z = 0.67
	for x in [-0.16, 0.085]:
		var sandwich := _pivot(root, "StarSandwich", Vector3(x, 0.146, 0.07))
		sandwich.rotation.x = -PI * 0.5
		sandwich.scale = Vector3.ONE * 0.13
		# Compact stars use flattened ellipsoid lobes, with visible jam between bread.
		for layer in range(3):
			var mat: Material = p.pink if layer == 1 else p.gold
			_decor_ball(sandwich, "SandwichCenter", Vector3(0, 0, layer * 0.17), Vector3(1.0, 1.0, 0.22), mat)
			for i in range(5):
				var angle := TAU * float(i) / 5.0
				var lobe := _decor_ball(sandwich, "BreadPoint", Vector3(sin(angle) * 0.44, cos(angle) * 0.44, layer * 0.17), Vector3(0.51, 0.87, 0.22), mat)
				lobe.rotation.z = -angle
	var thermos := _pivot(root, "Thermos", Vector3(-0.43, 0.06, -0.30))
	_decor_tube(thermos, "VacuumFlask", Vector3(0, 0.235, 0), 0.096, 0.45, p.blue)
	_decor_ring(thermos, "FlaskBaseBumper", Vector3(0, 0.03, 0), 0.093, 0.012, p.cream)
	_decor_tube(thermos, "CupLid", Vector3(0, 0.481, 0), 0.10, 0.085, p.cream)
	_decor_ring(thermos, "LidSeam", Vector3(0, 0.441, 0), 0.098, 0.006, p.gold)
	_decor_arc(thermos, "FlaskMoon", Vector3(0, 0.255, 0.099), Vector2(0.033, 0.045), 0.6, TAU - 0.6, 0.009, p.gold)
	_decor_cup(root, Vector3(0.39, 0.061, 0.28), 0.77, p.lilac, p.cream, p.soil)
	var roll := _pivot(root, "RolledStargazingBlanket", Vector3(0.33, 0.175, -0.30))
	roll.rotation.z = PI * 0.5
	_decor_tube(roll, "BlanketRoll", Vector3.ZERO, 0.12, 0.40, p.lilac)
	for y in [-0.13, 0.13]:
		_decor_ring(roll, "RollStrap", Vector3(0, y, 0), 0.12, 0.014, p.gold)
	for radius in [0.043, 0.083]:
		_decor_ring(roll, "RolledFabricLayers", Vector3(0, -0.202, 0), radius, 0.007, p.cream)
	_decor_book(root, Vector3(-0.35, 0.090, 0.36), 0.66, p.teal, p.cream, p.soil, p.lilac)


static func _crystal_terrarium(root: Node3D, p: Dictionary) -> void:
	# A bell jar with visible substrate, faceted crystals, moss, and a brass frame.
	_decor_tube(root, "CeramicTerrariumTray", Vector3(0, 0.072, 0), 0.52, 0.144, p.peach)
	_decor_ring(root, "TrayFoot", Vector3(0, 0.027, 0), 0.445, 0.027, p.teal)
	_decor_ring(root, "TrayLip", Vector3(0, 0.146, 0), 0.50, 0.025, p.cream)
	_decor_tube(root, "LayerOfSand", Vector3(0, 0.154, 0), 0.459, 0.034, p.gold)
	_decor_tube(root, "MossSoil", Vector3(0, 0.180, 0), 0.445, 0.025, p.soil)
	for i in range(7):
		var a := TAU * float(i) / 7.0
		_decor_ball(root, "MossPillow", Vector3(cos(a) * 0.29, 0.217, sin(a) * 0.27), Vector3(0.24, 0.089, 0.21), p.mint if i % 2 == 0 else p.teal)
	for i in range(5):
		var crystal := _pivot(root, "CrystalCluster", [Vector3(-0.06, 0.205, -0.05), Vector3(-0.23, 0.205, 0.045), Vector3(0.17, 0.205, -0.13), Vector3(0.13, 0.205, 0.13), Vector3(-0.03, 0.205, 0.20)][i])
		crystal.rotation = Vector3([0.04, -0.12, 0.12, 0.16, -0.08][i], float(i) * 0.8, [-0.08, 0.24, -0.23, -0.17, 0.14][i])
		var height: float = [0.62, 0.34, 0.46, 0.30, 0.24][i]
		var width: float = [0.097, 0.074, 0.081, 0.069, 0.052][i]
		var crystal_mat := _material([LILAC, BLUE, PINK, BLUE, LILAC][i], true, 0.07)
		var shaft := CylinderMesh.new()
		shaft.bottom_radius = width
		shaft.top_radius = width * 0.90
		shaft.height = height * 0.72
		shaft.radial_segments = 6
		_mesh(crystal, "HexagonalCrystal", shaft, Vector3(0, height * 0.36, 0), crystal_mat)
		var tip := CylinderMesh.new()
		tip.bottom_radius = width * 0.90
		tip.top_radius = 0
		tip.height = height * 0.28
		tip.radial_segments = 6
		_mesh(crystal, "CrystalTermination", tip, Vector3(0, height * 0.86, 0), crystal_mat)
		_decor_stem(crystal, "CrystalEdgeGlint", Vector3(-width * 0.43, height * 0.22, width * 0.82), Vector3(-width * 0.40, height * 0.62, width * 0.76), 0.003, p.cream)
	for i in range(5):
		_decor_ball(root, "PolishedPebble", Vector3(-0.28 + i * 0.115, 0.207, 0.303), Vector3(0.070, 0.039, 0.055), p.cream if i % 2 == 0 else p.blue)
	var glass := _material(Color(0.70, 0.91, 0.90, 0.12), true)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	# An open cylindrical wall rises into a hemispherical bell, with no collapsed
	# faces or buried bottom cap. The tray seals the jar at Y=0.165.
	var jar_vertices := PackedVector3Array()
	var jar_normals := PackedVector3Array()
	var jar_indices := PackedInt32Array()
	for row in range(10):
		var elevation := maxf(0.0, float(row - 1)) / 8.0 * PI * 0.5
		var radius := 0.47 * cos(elevation)
		var y := 0.165 if row == 0 else 0.593 + 0.47 * sin(elevation)
		for col in range(24):
			var angle := TAU * float(col) / 24.0
			jar_vertices.append(Vector3(cos(angle) * radius, y, sin(angle) * radius))
			jar_normals.append(Vector3(cos(angle) * cos(elevation), sin(elevation), sin(angle) * cos(elevation)))
			if row < 9:
				var a := row * 24 + col
				var b := row * 24 + (col + 1) % 24
				jar_indices.append_array(PackedInt32Array([a, b, a + 24]))
				if row < 8:
					jar_indices.append_array(PackedInt32Array([b, b + 24, a + 24]))
	var jar_arrays := []
	jar_arrays.resize(Mesh.ARRAY_MAX)
	jar_arrays[Mesh.ARRAY_VERTEX] = jar_vertices
	jar_arrays[Mesh.ARRAY_NORMAL] = jar_normals
	jar_arrays[Mesh.ARRAY_INDEX] = jar_indices
	var jar := ArrayMesh.new()
	jar.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, jar_arrays)
	_mesh(root, "ClearBellJar", jar, Vector3.ZERO, glass)
	_decor_ring(root, "GlassSeatingGasket", Vector3(0, 0.165, 0), 0.469, 0.015, p.gold)
	for side in [-1.0, 1.0]:
		_decor_curve(root, "BrassJarRib", PackedVector3Array([Vector3(side * 0.469, 0.16, 0), Vector3(side * 0.47, 0.59, 0), Vector3(side * 0.435, 0.77, 0), Vector3(side * 0.30, 0.96, 0), Vector3(0, 1.065, 0)]), 0.010, p.gold)
	_decor_tube(root, "LidButtonBase", Vector3(0, 1.075, 0), 0.074, 0.030, p.cream)
	_decor_ball(root, "GlassLiftingKnob", Vector3(0, 1.135, 0), Vector3(0.12, 0.12, 0.12), p.mint)
	_decor_curve(root, "GlassReflection", PackedVector3Array([Vector3(-0.30, 0.45, 0.35), Vector3(-0.30, 0.63, 0.35), Vector3(-0.275, 0.74, 0.335)]), 0.009, p.white)
	_decor_box(root, "SpecimenLabel", Vector3(0, 0.091, 0.519), Vector3(0.22, 0.082, 0.018), 0.008, p.cream)
	for x in [-0.050, 0, 0.05]:
		_decor_ball(root, "LabelConstellation", Vector3(x, 0.093 + (0.012 if x == 0 else -0.008), 0.53), Vector3.ONE * 0.012, p.teal)
