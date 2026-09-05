extends RefCounted
## Standalone neighbor architecture. +Z is front; root Y=0 is tangent ground.
## Foundation skirts reach -0.14 to meet the curved world; entry tops stay at 0.18.
## World may recolor the direct RoofCap/DoorFrame meshes, then merge all surfaces.
## No attached scripts, animation, physics or interaction: World owns those systems.

const Art = preload("res://scripts/art.gd")


static func make(style: int) -> Node3D:
	# Styles 4/5 are planet IDs, not a new modulo for legacy styles.
	if style == 4:
		return _courier_home()
	if style == 5:
		return _bakery_home()
	match posmod(style, 3):
		1:
			return _garden_home()
		2:
			return _workshop_home()
	return Art.building(0)


static func _paint(color: String, roughness: float = 0.68, metal: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = roughness
	material.metallic = metal
	return material


# Extrude a cross section as one closed mesh. Facade caps stay flat; each edge
# receives its own outward normal so joinery and sheet thickness catch the light.
static func _section(parent: Node3D, label: String, outline: PackedVector2Array, back: float, front: float, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var polygon := outline
	if Geometry2D.is_polygon_clockwise(polygon):
		polygon.reverse()
	var cap_indices := Geometry2D.triangulate_polygon(polygon)
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, cap_indices.size(), 3):
		var a: Vector2 = polygon[cap_indices[i]]
		var b: Vector2 = polygon[cap_indices[i + 1]]
		var c: Vector2 = polygon[cap_indices[i + 2]]
		_triangle(builder, Vector3(a.x, a.y, front), Vector3(b.x, b.y, front), Vector3(c.x, c.y, front), Vector3.BACK)
		_triangle(builder, Vector3(a.x, a.y, back), Vector3(b.x, b.y, back), Vector3(c.x, c.y, back), Vector3.FORWARD)
	for i in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		var delta := b - a
		var normal := Vector3(delta.y, -delta.x, 0).normalized()
		var ab := Vector3(a.x, a.y, back)
		var af := Vector3(a.x, a.y, front)
		var bb := Vector3(b.x, b.y, back)
		var bf := Vector3(b.x, b.y, front)
		_triangle(builder, ab, af, bb, normal)
		_triangle(builder, af, bf, bb, normal)
	builder.index()
	return Art._mesh(parent, label, builder.commit(), pos, mat)


static func _triangle(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	# Godot's front face is clockwise. Orient every cap and side from its normal.
	builder.set_normal(normal)
	builder.add_vertex(a)
	if (c - a).cross(b - a).dot(normal) >= 0.0:
		builder.add_vertex(b)
		builder.add_vertex(c)
	else:
		builder.add_vertex(c)
		builder.add_vertex(b)


static func _arched_panel(parent: Node3D, label: String, pos: Vector3, width: float, height: float, thickness: float, mat: Material) -> MeshInstance3D:
	var radius := width * 0.5
	var spring := height * 0.5 - radius
	var outline := PackedVector2Array([Vector2(-radius, -height * 0.5), Vector2(radius, -height * 0.5)])
	for i in range(17):
		var angle := PI * float(i) / 16.0
		outline.append(Vector2(cos(angle) * radius, spring + sin(angle) * radius))
	return _section(parent, label, outline, -thickness * 0.5, thickness * 0.5, mat, pos)


static func _beam(parent: Node3D, label: String, a: Vector3, b: Vector3, width: float, depth: float, mat: Material) -> MeshInstance3D:
	var delta := b - a
	var beam := Art._decor_box(parent, label, (a + b) * 0.5, Vector3(width, delta.length(), depth), minf(width, depth) * 0.22, mat)
	beam.quaternion = Quaternion(Vector3.UP, delta.normalized())
	return beam


static func _entry_steps(parent: Node3D, base: Material, tread: Material, grip: Material = null) -> void:
	# Three short risers follow the drop of the tiny planet toward the path.
	# The upper threshold and buried skirt retain their existing heights.
	for index in range(3):
		var top := 0.18 - float(index) * 0.135
		var height := top + 0.14
		var z := 0.78 + float(index) * 0.099
		Art._decor_box(parent, ["WelcomeStep", "MiddleEntryStep", "LowerEntryStep"][index], Vector3(0, top - height * 0.5, z), Vector3(0.64, height, 0.108), minf(0.025, height * 0.3), base)
		Art._decor_box(parent, ["ThresholdTread", "MiddleTread", "LowerTread"][index], Vector3(0, top - 0.003, z), Vector3(0.61, 0.018, 0.093), 0.008, tread)
		if grip != null:
			for x in [-0.19, 0.0, 0.19]:
				Art._decor_box(parent, "TreadGrip", Vector3(x, top + 0.010, z), Vector3(0.024, 0.009, 0.071), 0.004, grip)


static func _garden_home() -> Node3D:
	var root := Art._root("LumiGardenHome")
	var plaster := _paint("eee0c5", 0.86)
	var ivory := _paint("f5e6c9", 0.66)
	var timber := _paint("b29679", 0.82)
	var roof := _paint("b5a0d1", 0.67)
	var frame := _paint("c4afdb", 0.60)
	var sage := _paint("7fa99a", 0.75)
	var soil := _paint("746b68", 0.96)
	var leaf := _paint("91bda1", 0.91)
	var leaf_light := _paint("b6d1aa", 0.91)
	var bloom := _paint("dba7b8", 0.84)
	var glass := _paint("7098a2", 0.27)
	var brass := _paint("cdb37f", 0.36, 0.26)

	Art._decor_box(root, "GardenFoundation", Vector3(0, 0.02, -0.065), Vector3(1.49, 0.32, 1.22), 0.08, sage)
	Art._decor_box(root, "SillCourse", Vector3(0, 0.20, -0.065), Vector3(1.44, 0.08, 1.18), 0.039, ivory)
	Art._decor_box(root, "PlasterWalls", Vector3(0, 0.745, -0.065), Vector3(1.38, 1.05, 1.10), 0.14, plaster)
	# A deep, curved gable follows the roof rather than retaining the original pod.
	var gable := PackedVector2Array([Vector2(-0.66, 1.20), Vector2(0.66, 1.20)])
	for i in range(15):
		var x := 0.66 - float(i) * 1.32 / 14.0
		gable.append(Vector2(x, 1.27 + 0.47 * (1.0 - pow(absf(x / 0.73), 1.35))))
	_section(root, "CurvedGableWalls", gable, -0.57, 0.485, plaster)
	var roof_outline := PackedVector2Array()
	for i in range(21):
		var x := -0.79 + float(i) * 1.58 / 20.0
		roof_outline.append(Vector2(x, 1.34 + 0.49 * (1.0 - pow(absf(x / 0.79), 1.35))))
	for i in range(20, -1, -1):
		var point := roof_outline[i]
		roof_outline.append(point - Vector2(0, 0.075))
	_section(root, "RoofCap", roof_outline, -0.655, 0.565, roof)
	_section(root, "FrontCurvedFascia", roof_outline, 0.568, 0.604, ivory)
	Art._decor_stem(root, "RoundedRidgeCap", Vector3(0, 1.838, -0.636), Vector3(0, 1.838, 0.585), 0.032, roof)
	for side in [-1.0, 1.0]:
		Art._decor_stem(root, "EaveGutter", Vector3(side * 0.767, 1.30, -0.62), Vector3(side * 0.767, 1.30, 0.55), 0.030, sage)
		Art._decor_box(root, "CornerTimber", Vector3(side * 0.615, 0.76, 0.465), Vector3(0.069, 0.97, 0.068), 0.016, timber)
	# Raised fanlight within the front gable; the central aerial remains World's.
	_arched_panel(root, "FanlightFrame", Vector3(0, 1.49, 0.508), 0.28, 0.31, 0.050, timber)
	_arched_panel(root, "FanlightGlass", Vector3(0, 1.49, 0.538), 0.217, 0.247, 0.019, glass)
	Art._decor_stem(root, "FanlightMullion", Vector3(0, 1.38, 0.552), Vector3(0, 1.597, 0.552), 0.013, ivory)

	# A narrow vestibule holds the door at the existing interaction depth.
	Art._decor_box(root, "PorchVestibule", Vector3(0, 0.70, 0.615), Vector3(0.60, 0.94, 0.30), 0.075, plaster)
	_arched_panel(root, "DoorFrame", Vector3(0, 0.68, 0.784), 0.53, 0.97, 0.060, frame)
	_arched_panel(root, "Door", Vector3(0, 0.672, 0.824), 0.421, 0.856, 0.023, sage)
	for x in [-0.105, 0.0, 0.105]:
		Art._decor_stem(root, "DoorBoardJoint", Vector3(x, 0.29, 0.838), Vector3(x, 0.73, 0.838), 0.005, timber)
	_arched_panel(root, "DoorLightFrame", Vector3(0, 0.895, 0.842), 0.21, 0.245, 0.015, ivory)
	_arched_panel(root, "DoorLight", Vector3(0, 0.895, 0.853), 0.155, 0.185, 0.012, glass)
	Art._decor_ball(root, "DoorLatch", Vector3(0.132, 0.588, 0.861), Vector3(0.042, 0.055, 0.033), brass)
	_entry_steps(root, timber, ivory)
	var canopy := PackedVector2Array([Vector2(-0.405, 1.175), Vector2(0, 1.273), Vector2(0.405, 1.175), Vector2(0.385, 1.245), Vector2(0, 1.344), Vector2(-0.385, 1.245)])
	_section(root, "PorchRoof", canopy, 0.585, 0.933, roof)
	_section(root, "PorchFrontFascia", canopy, 0.933, 0.955, ivory)
	for side in [-1.0, 1.0]:
		_beam(root, "PorchPost", Vector3(side * 0.307, 0.17, 0.866), Vector3(side * 0.307, 1.225, 0.866), 0.055, 0.065, timber)
		Art._decor_box(root, "PostShoe", Vector3(side * 0.307, 0.242, 0.866), Vector3(0.078, 0.13, 0.084), 0.018, sage)
		_beam(root, "PorchKneeBrace", Vector3(side * 0.30, 1.015, 0.866), Vector3(side * 0.175, 1.215, 0.866), 0.04, 0.043, timber)

	# A projecting, divided bay sits on its own sill and built-in herb box.
	Art._decor_box(root, "BayWindowHousing", Vector3(-0.475, 0.876, 0.559), Vector3(0.375, 0.51, 0.19), 0.054, timber)
	Art._decor_box(root, "BayWindowRebate", Vector3(-0.475, 0.882, 0.660), Vector3(0.310, 0.427, 0.035), 0.017, ivory)
	Art._decor_box(root, "BayWindowGlass", Vector3(-0.475, 0.888, 0.682), Vector3(0.256, 0.369, 0.015), 0.007, glass)
	Art._decor_box(root, "BayVerticalMullion", Vector3(-0.475, 0.888, 0.697), Vector3(0.026, 0.380, 0.022), 0.008, ivory)
	Art._decor_box(root, "BayTransom", Vector3(-0.475, 0.953, 0.697), Vector3(0.270, 0.024, 0.022), 0.008, ivory)
	Art._decor_box(root, "DeepWindowSill", Vector3(-0.475, 0.620, 0.602), Vector3(0.432, 0.065, 0.268), 0.027, ivory)
	Art._decor_box(root, "IntegratedWindowPlanter", Vector3(-0.48, 0.493, 0.622), Vector3(0.40, 0.19, 0.265), 0.051, sage)
	Art._decor_box(root, "WindowPlanterSoil", Vector3(-0.48, 0.589, 0.624), Vector3(0.337, 0.018, 0.20), 0.008, soil)
	for i in range(3):
		var x := -0.592 + float(i) * 0.112
		Art._decor_ball(root, "WindowsillHerb", Vector3(x, 0.643, 0.67), Vector3(0.12, 0.14, 0.12), leaf_light)
		Art._decor_leaf(root, Vector3(x + 0.025, 0.691, 0.65), 0.15, -0.65, leaf)

	# The growing edge is part of the foundation, not another detached flowerpot.
	Art._decor_box(root, "GrowingEdgeSkirt", Vector3(-0.765, 0.02, -0.145), Vector3(0.265, 0.32, 0.66), 0.070, sage)
	Art._decor_box(root, "GrowingEdgeSoil", Vector3(-0.773, 0.184, -0.145), Vector3(0.20, 0.024, 0.58), 0.011, soil)
	for i in range(3):
		var z := -0.355 + float(i) * 0.21
		var top := 0.96 + float(i % 2) * 0.16
		Art._decor_curve(root, "TrainedStem", PackedVector3Array([Vector3(-0.80, 0.20, z), Vector3(-0.815, 0.46, z), Vector3(-0.775, 0.70, z), Vector3(-0.73, top, z)]), 0.014, timber)
		for j in range(3):
			var blade := Art._decor_ball(root, "BroadClimbingLeaf", Vector3(-0.80, 0.39 + float(j) * 0.205, z + (0.035 if j % 2 == 0 else -0.035)), Vector3(0.084, 0.25, 0.15), leaf if j % 2 == 0 else leaf_light)
			blade.rotation.x = 0.48 if j % 2 == 0 else -0.48
		Art._decor_ball(root, "GardenBellBud", Vector3(-0.743, top, z), Vector3(0.095, 0.13, 0.095), bloom)
	return root


static func _workshop_home() -> Node3D:
	var root := Art._root("BoltWorkshopHome")
	var plaster := _paint("e9dbc1", 0.81)
	var ivory := _paint("e8d9ba", 0.70)
	var copper := _paint("c88d68", 0.53, 0.12)
	var steel := _paint("789bb7", 0.54, 0.16)
	var dark_metal := _paint("536c74", 0.57, 0.22)
	var rubber := _paint("536067", 0.94)
	var glass := _paint("79a5ad", 0.25)
	var brass := _paint("c7ad76", 0.37, 0.30)
	var timber := _paint("ab8968", 0.84)

	Art._decor_box(root, "WorkshopFoundation", Vector3(0, 0.02, -0.07), Vector3(1.49, 0.32, 1.22), 0.075, dark_metal)
	Art._decor_box(root, "BaseChannel", Vector3(0, 0.206, -0.07), Vector3(1.45, 0.071, 1.18), 0.033, steel)
	Art._decor_box(root, "WorkshopWalls", Vector3(0, 0.789, -0.075), Vector3(1.39, 1.12, 1.09), 0.085, plaster)
	# An asymmetric shed roof rises toward the service vent. Its front wall leaves
	# a clear mounting area for World's one gear at (0.36, 1.43, 0.48).
	var upper_wall := PackedVector2Array([Vector2(-0.665, 1.27), Vector2(0.665, 1.27), Vector2(0.665, 1.713), Vector2(-0.665, 1.455)])
	_section(root, "UpperWorkshopWall", upper_wall, -0.595, 0.459, plaster)
	var roof_section := PackedVector2Array([Vector2(-0.785, 1.405), Vector2(0.785, 1.710), Vector2(0.785, 1.796), Vector2(-0.785, 1.491)])
	_section(root, "RoofCap", roof_section, -0.66, 0.575, copper)
	_section(root, "FrontFoldedFascia", roof_section, 0.575, 0.605, ivory)
	for x in [-0.55, -0.16, 0.23, 0.62]:
		var y: float = 1.491 + (x + 0.785) * 0.305 / 1.57 + 0.011
		Art._decor_box(root, "StandingRoofSeam", Vector3(x, y, -0.027), Vector3(0.027, 0.032, 1.24), 0.012, copper)
	for side in [-1.0, 1.0]:
		var y := 1.465 if side < 0 else 1.770
		Art._decor_box(root, "FoldedSideRoofEdge", Vector3(side * 0.777, y, -0.027), Vector3(0.052, 0.093, 1.23), 0.022, steel)
		Art._decor_box(root, "CornerAnglePost", Vector3(side * 0.651, 0.815, 0.456), Vector3(0.071, 1.10, 0.078), 0.018, steel)
	# A low exhaust cowl is utility construction; no second gear or aerial is added.
	Art._decor_box(root, "VentFlashing", Vector3(0.475, 1.767, -0.29), Vector3(0.30, 0.060, 0.31), 0.025, dark_metal).rotation.z = 0.192
	Art._decor_box(root, "VentStack", Vector3(0.475, 1.872, -0.29), Vector3(0.20, 0.21, 0.20), 0.043, copper)
	Art._decor_box(root, "VentRainCap", Vector3(0.475, 1.99, -0.29), Vector3(0.31, 0.055, 0.30), 0.026, ivory)
	for y in [1.86, 1.915]:
		Art._decor_box(root, "VentLouver", Vector3(0.475, y, -0.183), Vector3(0.147, 0.016, 0.026), 0.007, dark_metal)

	# Taller hatch vestibule retains the same central doorway and approach lane.
	Art._decor_box(root, "HatchVestibule", Vector3(0, 0.704, 0.618), Vector3(0.60, 0.98, 0.30), 0.072, plaster)
	Art._decor_box(root, "DoorFrame", Vector3(0, 0.69, 0.784), Vector3(0.535, 0.98, 0.065), 0.030, steel)
	Art._decor_box(root, "HatchGasket", Vector3(0, 0.69, 0.823), Vector3(0.465, 0.91, 0.018), 0.008, rubber)
	Art._decor_box(root, "Door", Vector3(0, 0.683, 0.841), Vector3(0.420, 0.854, 0.025), 0.012, ivory)
	Art._decor_box(root, "LowerHatchPanel", Vector3(0, 0.454, 0.859), Vector3(0.34, 0.282, 0.013), 0.006, steel)
	Art._decor_box(root, "HatchCrossRail", Vector3(0, 0.626, 0.864), Vector3(0.41, 0.039, 0.023), 0.010, dark_metal)
	Art._decor_box(root, "HatchWindowRebate", Vector3(0, 0.908, 0.862), Vector3(0.256, 0.213, 0.022), 0.010, steel)
	Art._decor_box(root, "HatchWindow", Vector3(0, 0.908, 0.877), Vector3(0.202, 0.157, 0.015), 0.007, glass)
	for y in [0.436, 0.946]:
		Art._decor_box(root, "HatchHinge", Vector3(-0.227, y, 0.853), Vector3(0.047, 0.11, 0.046), 0.019, brass)
	Art._decor_curve(root, "LeverLatch", PackedVector3Array([Vector3(0.133, 0.675, 0.858), Vector3(0.133, 0.675, 0.905), Vector3(0.069, 0.675, 0.905)]), 0.014, dark_metal)
	_entry_steps(root, dark_metal, steel, ivory)
	Art._decor_box(root, "EntryRainBrow", Vector3(0, 1.233, 0.71), Vector3(0.65, 0.070, 0.42), 0.032, copper).rotation.x = 0.095
	for side in [-1.0, 1.0]:
		_beam(root, "BrowBracket", Vector3(side * 0.245, 1.066, 0.624), Vector3(side * 0.245, 1.203, 0.832), 0.036, 0.041, dark_metal)

	# Wide horizontal glazing with a deep industrial sill, independent of the hatch.
	Art._decor_box(root, "ClerestoryFrame", Vector3(-0.414, 1.278, 0.488), Vector3(0.43, 0.257, 0.091), 0.033, dark_metal)
	Art._decor_box(root, "ClerestoryGlass", Vector3(-0.414, 1.278, 0.538), Vector3(0.353, 0.181, 0.022), 0.010, glass)
	Art._decor_box(root, "ClerestoryDivider", Vector3(-0.424, 1.278, 0.555), Vector3(0.023, 0.185, 0.025), 0.010, ivory)
	Art._decor_box(root, "MetalWindowSill", Vector3(-0.414, 1.128, 0.517), Vector3(0.47, 0.044, 0.175), 0.020, steel)
	Art._decor_box(root, "LowServiceShelf", Vector3(-0.485, 0.615, 0.561), Vector3(0.39, 0.069, 0.238), 0.030, timber)
	for x in [-0.61, -0.36]:
		_beam(root, "ShelfKnee", Vector3(x, 0.455, 0.466), Vector3(x, 0.582, 0.621), 0.036, 0.041, dark_metal)

	# A separate side access hatch and an external service loop articulate the shell.
	var service := Art._pivot(root, "RightServiceHatch", Vector3(0.697, 0.731, -0.08))
	service.rotation.y = PI * 0.5
	Art._decor_box(service, "ServiceRebate", Vector3.ZERO, Vector3(0.49, 0.57, 0.080), 0.037, dark_metal)
	Art._decor_box(service, "ServicePanel", Vector3(0, 0, 0.052), Vector3(0.419, 0.499, 0.044), 0.021, steel)
	for y in [-0.14, 0.14]:
		Art._decor_box(service, "ServiceHinge", Vector3(-0.20, y, 0.078), Vector3(0.060, 0.10, 0.039), 0.018, brass)
	Art._decor_curve(service, "ServiceGrabHandle", PackedVector3Array([Vector3(0.12, -0.07, 0.081), Vector3(0.12, -0.07, 0.13), Vector3(0.12, 0.07, 0.13), Vector3(0.12, 0.07, 0.081)]), 0.012, dark_metal)
	for y in [-0.04, 0.035, 0.11]:
		Art._decor_box(service, "InsetPanelLouver", Vector3(-0.036, y, 0.078), Vector3(0.19, 0.020, 0.017), 0.008, rubber)
	Art._decor_box(root, "UtilityMountingFoot", Vector3(-0.786, 0.02, -0.223), Vector3(0.24, 0.32, 0.46), 0.053, dark_metal)
	Art._decor_tube(root, "CoolantCanister", Vector3(-0.79, 0.538, -0.255), 0.099, 0.69, ivory)
	Art._decor_ball(root, "CanisterShoulder", Vector3(-0.79, 0.868, -0.255), Vector3(0.198, 0.097, 0.198), ivory)
	for y in [0.32, 0.73]:
		Art._decor_ring(root, "CanisterStrap", Vector3(-0.79, y, -0.255), 0.10, 0.012, copper)
	Art._decor_curve(root, "UpperCoolantReturn", PackedVector3Array([Vector3(-0.79, 0.905, -0.255), Vector3(-0.79, 1.02, -0.255), Vector3(-0.74, 1.076, -0.255), Vector3(-0.676, 1.076, -0.255)]), 0.025, copper)
	Art._decor_curve(root, "LowerUtilityPipe", PackedVector3Array([Vector3(-0.79, 0.265, -0.255), Vector3(-0.79, 0.265, -0.03), Vector3(-0.77, 0.40, 0.03), Vector3(-0.676, 0.40, 0.03)]), 0.024, dark_metal)
	return root


static func _courier_home() -> Node3D:
	var root := Art._root("PipMoonWaystation")
	var stone := _paint("7499b0")
	var ice := _paint("d7e8e9")
	var blue := _paint("7dbbd6")
	var slate := _paint("456780")
	var glass := _paint("597f9c", 0.25)
	var brass := _paint("d8be83", 0.4, 0.2)
	# A compact barrel vault, with an inset crescent and a sheltered mail slot.
	Art._decor_box(root, "CourierFoundation", Vector3(0, 0.02, -0.06), Vector3(1.44, 0.32, 1.20), 0.09, stone)
	_arched_panel(root, "VaultedWalls", Vector3(0, 0.83, -0.07), 1.30, 1.34, 1.02, ice)
	var shell := PackedVector2Array()
	for i in range(25):
		var angle := PI * float(i) / 24.0
		shell.append(Vector2(cos(angle) * 0.73, 0.87 + sin(angle) * 0.73))
	for i in range(24, -1, -1):
		var angle := PI * float(i) / 24.0
		shell.append(Vector2(cos(angle) * 0.66, 0.87 + sin(angle) * 0.66))
	_section(root, "RoofCap", shell, -0.64, 0.57, blue)
	_section(root, "VaultFrontRim", shell, 0.57, 0.60, ice)
	for z in [-0.48, -0.16, 0.16]:
		Art._decor_arc(root, "VaultRib", Vector3(0, 0.87, z), Vector2(0.735, 0.735), 0, PI, 0.015, slate)
	Art._decor_box(root, "EntryAirlock", Vector3(0, 0.64, 0.61), Vector3(0.58, 0.91, 0.28), 0.08, ice)
	_arched_panel(root, "DoorFrame", Vector3(0, 0.67, 0.772), 0.52, 0.98, 0.055, blue)
	_arched_panel(root, "Door", Vector3(0, 0.66, 0.808), 0.42, 0.85, 0.025, slate)
	Art._decor_ring(root, "DoorPorthole", Vector3(0, 0.85, 0.834), 0.097, 0.018, brass, true)
	Art._decor_ball(root, "DoorGlass", Vector3(0, 0.85, 0.828), Vector3(0.16, 0.16, 0.018), glass)
	Art._decor_box(root, "DoorPull", Vector3(0.125, 0.55, 0.84), Vector3(0.028, 0.11, 0.024), 0.01, brass)
	_entry_steps(root, stone, ice)
	Art._decor_arc(root, "MoonAddress", Vector3(0, 1.31, 0.554), Vector2(0.10, 0.13), 0.65, TAU - 0.65, 0.028, brass)
	# The mail cabinet and moon garden are attached to the house foundation.
	Art._decor_box(root, "MailCabinet", Vector3(-0.46, 0.71, 0.58), Vector3(0.27, 0.38, 0.19), 0.045, blue)
	Art._decor_box(root, "LetterSlot", Vector3(-0.46, 0.77, 0.68), Vector3(0.18, 0.029, 0.013), 0.006, slate)
	Art._decor_box(root, "ParcelDrawer", Vector3(-0.46, 0.63, 0.68), Vector3(0.21, 0.13, 0.024), 0.012, ice)
	Art._decor_ball(root, "DrawerKnob", Vector3(-0.46, 0.65, 0.70), Vector3.ONE * 0.034, brass)
	Art._decor_box(root, "MoonGardenBed", Vector3(0.48, 0.23, 0.56), Vector3(0.30, 0.13, 0.28), 0.04, slate)
	for i in range(3):
		var x := 0.39 + i * 0.085
		Art._decor_stem(root, "SilverStem", Vector3(x, 0.29, 0.55), Vector3(x, 0.48 + i * 0.065, 0.55), 0.013, stone)
		Art._decor_ball(root, "MoonBloom", Vector3(x, 0.50 + i * 0.065, 0.55), Vector3(0.074, 0.10, 0.074), ice)
		Art._decor_leaf(root, Vector3(x, 0.39, 0.55), 0.10, -0.6, blue)
	Art._decor_ring(root, "RoundSideWindow", Vector3(0.44, 0.96, 0.49), 0.112, 0.023, stone, true)
	Art._decor_ball(root, "SideGlass", Vector3(0.44, 0.96, 0.489), Vector3(0.19, 0.19, 0.02), glass)
	return root


static func _bakery_home() -> Node3D:
	var root := Art._root("MisoMeadowBakery")
	var cream := _paint("f5e4c3")
	var apricot := _paint("e4a072")
	var crust := _paint("ab7954")
	var meadow := _paint("95ad85")
	var glass := _paint("796b59", 0.3)
	var bread := _paint("e3ba76")
	Art._decor_box(root, "BakeryFoundation", Vector3(0, 0.02, -0.06), Vector3(1.46, 0.32, 1.20), 0.075, meadow)
	Art._decor_box(root, "BakeryWalls", Vector3(0, 0.78, -0.06), Vector3(1.34, 1.20, 1.06), 0.12, cream)
	var gable := PackedVector2Array([Vector2(-0.66, 1.29), Vector2(0.66, 1.29), Vector2(0, 1.77)])
	_section(root, "BakeryGable", gable, -0.59, 0.47, cream)
	var roof := PackedVector2Array([Vector2(-0.76, 1.29), Vector2(0, 1.79), Vector2(0.76, 1.29), Vector2(0.76, 1.39), Vector2(0, 1.89), Vector2(-0.76, 1.39)])
	_section(root, "RoofCap", roof, -0.65, 0.58, apricot)
	_section(root, "GingerbreadFascia", roof, 0.58, 0.61, cream)
	for side in [-1.0, 1.0]:
		for i in range(3):
			var x: float = side * (0.17 + i * 0.20)
			Art._decor_stem(root, "TileCourse", Vector3(x, 1.90 - absf(x) * 0.658, -0.61), Vector3(x, 1.90 - absf(x) * 0.658, 0.55), 0.017, crust)
	Art._decor_box(root, "OvenChimney", Vector3(-0.41, 1.68, -0.30), Vector3(0.20, 0.57, 0.23), 0.025, crust)
	Art._decor_box(root, "ChimneyCap", Vector3(-0.41, 1.98, -0.30), Vector3(0.28, 0.065, 0.29), 0.022, cream)
	Art._decor_box(root, "EntryVestibule", Vector3(0, 0.63, 0.61), Vector3(0.56, 0.90, 0.29), 0.055, cream)
	_arched_panel(root, "DoorFrame", Vector3(0, 0.66, 0.78), 0.52, 0.96, 0.055, apricot)
	_arched_panel(root, "Door", Vector3(0, 0.66, 0.819), 0.42, 0.85, 0.024, meadow)
	_arched_panel(root, "DoorWindow", Vector3(0, 0.83, 0.839), 0.22, 0.29, 0.013, glass)
	Art._decor_ball(root, "DoorHandle", Vector3(0.125, 0.55, 0.851), Vector3.ONE * 0.036, crust)
	_entry_steps(root, crust, cream)
	# A shallow striped awning and a bread-filled display distinguish the facade.
	Art._decor_box(root, "BreadWindowFrame", Vector3(-0.465, 0.86, 0.50), Vector3(0.32, 0.43, 0.08), 0.035, crust)
	Art._decor_box(root, "BreadWindow", Vector3(-0.465, 0.86, 0.549), Vector3(0.26, 0.35, 0.024), 0.011, glass)
	Art._decor_box(root, "DisplayShelf", Vector3(-0.465, 0.70, 0.61), Vector3(0.35, 0.038, 0.18), 0.017, cream)
	for i in range(3):
		var x := -0.565 + i * 0.10
		Art._decor_ball(root, "FreshLoaf", Vector3(x, 0.76, 0.59), Vector3(0.083, 0.09, 0.14), bread)
		Art._decor_stem(root, "LoafScore", Vector3(x - 0.018, 0.80, 0.59), Vector3(x + 0.018, 0.80, 0.61), 0.006, cream)
	for i in range(5):
		var x := -0.625 + i * 0.08
		Art._decor_box(root, "AwningStripe", Vector3(x, 1.13, 0.59), Vector3(0.08, 0.06, 0.29), 0.012, meadow if i % 2 == 0 else cream)
		Art._decor_ball(root, "AwningScallop", Vector3(x, 1.095, 0.725), Vector3(0.08, 0.10, 0.035), meadow if i % 2 == 0 else cream)
	Art._decor_ball(root, "LoafSign", Vector3(0.40, 1.08, 0.51), Vector3(0.29, 0.18, 0.065), bread)
	for x in [0.33, 0.40, 0.47]:
		Art._decor_stem(root, "SignScoring", Vector3(x - 0.018, 1.055, 0.547), Vector3(x + 0.012, 1.105, 0.547), 0.009, cream)
	Art._decor_box(root, "HerbTrough", Vector3(0.48, 0.265, 0.56), Vector3(0.29, 0.17, 0.27), 0.04, apricot)
	for x in [0.40, 0.49, 0.57]:
		Art._decor_ball(root, "KitchenHerbs", Vector3(x, 0.39, 0.56), Vector3(0.11, 0.15, 0.13), meadow)
	return root
