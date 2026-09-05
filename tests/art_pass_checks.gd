extends RefCounted
## Invoked by the full integration suite. Reads factories and generated worlds;
## exercises movement against their actual colliders. No production/save edits.
const Art = preload("res://scripts/art.gd")
const Homes = preload("res://scripts/homes.gd")
const Botany = preload("res://scripts/botany.gd")
var r: SceneTree
var game: Node

func run(runner: SceneTree) -> void:
	r = runner
	game = r.game
	if not _check(game.test_mode, "geometry fixtures require test_mode"):
		return
	_factories()
	_generated_worlds()
	_building_boundaries()

func _check(ok: bool, evidence: String) -> bool:
	return r._check(ok,"CRAFT: "+evidence)

func _measure(root: Node3D) -> Dictionary:
	var result := {"radius":0.0,"min_y":INF,"max_y":-INF,"min_z":INF,"max_z":-INF,"vertices":0,"finite":true}
	_accumulate(root,Transform3D.IDENTITY,result)
	return result

func _accumulate(node: Node3D, pose: Transform3D, result: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for surface in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point: Vector3 = pose*vertex
				result.finite = result.finite and point.is_finite()
				result.radius = maxf(result.radius,Vector2(point.x,point.z).length())
				result.min_y = minf(result.min_y,point.y)
				result.max_y = maxf(result.max_y,point.y)
				result.min_z = minf(result.min_z,point.z)
				result.max_z = maxf(result.max_z,point.z)
				result.vertices += 1
	for child in node.get_children():
		if child is Node3D:
			_accumulate(child,pose*child.transform,result)

func _factories() -> void:
	for style in [1,2]:
		var home := Homes.make(style)
		var bounds := _measure(home)
		_check(bounds.finite and bounds.vertices > 0 and bounds.radius <= 1.09, "home style %d stays finite and inside its declared footprint" % style)
		_check(absf(bounds.min_y+0.14) < 0.002 and absf(bounds.max_y-([1.87,2.0175][style-1])) < 0.015, "home style %d preserves buried floor and intended height" % style)
		_check(home.get_node_or_null("RoofCap") is MeshInstance3D and home.get_node_or_null("DoorFrame") is MeshInstance3D, "home style %d retains palette hooks" % style)
		var skirt: Node3D = home.get_node("GardenFoundation" if style == 1 else "WorkshopFoundation")
		var skirt_bounds := _measure(skirt)
		_check(is_equal_approx(float(skirt_bounds.min_y)+skirt.position.y,-0.14) and is_equal_approx(float(skirt_bounds.max_y)+skirt.position.y,0.18), "home style %d foundation extends downward while its top stays at 0.18" % style)
		_entry_steps(home,style)
		print("CRAFT_HOME_FACTORY: ",JSON.stringify({"style":style,"name":str(home.name),"bounds":bounds}))
		home.free()
	for style in range(4):
		var building := Art.building(style)
		var foundation: MeshInstance3D = building.get_node("Foundation")
		var bounds := _measure(foundation)
		_check(absf(float(bounds.min_y)+foundation.position.y+0.14) < 0.002 and absf(float(bounds.max_y)+foundation.position.y-0.18) < 0.002, "legacy building %d foundation has buried skirt and unchanged top" % style)
		building.free()
	for plant in [Botany.tree(),Botany.shrub()]:
		var meshes: Array[Node] = plant.find_children("*","MeshInstance3D",true,false)
		var mesh: Mesh = meshes[0].mesh if meshes.size() == 1 else null
		_check(mesh != null and mesh.get_surface_count() == 1, str(plant.name)+": one mesh surface")
		if mesh != null:
			var material: Material = mesh.surface_get_material(0)
			var arrays: Array = mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var finite := colors.size() == vertices.size() and normals.size() == vertices.size()
			for index in range(vertices.size()):
				finite = finite and vertices[index].is_finite() and normals[index].is_finite()
			_check(finite and material is StandardMaterial3D and material.vertex_color_use_as_albedo and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, str(plant.name)+": opaque material and complete finite vertex-color data")
			var bounds := _measure(plant)
			if plant.name == "CloverLeafShrub":
				_check(bounds.radius <= 0.60, "shrub geometry fits its registered full-plant collider")
			else:
				var trunk_radius := 0.0
				for point in vertices:
					if point.y < 0.40:
						trunk_radius = maxf(trunk_radius,Vector2(point.x,point.z).length())
				_check(trunk_radius <= 0.18, "new tree trunk fits its registered walking collider; canopy may overhang")
			print("CRAFT_PLANT_FACTORY: ",JSON.stringify({"name":str(plant.name),"bounds":bounds}))
		plant.free()

func _entry_steps(home: Node3D, style: int) -> void:
	var levels: Array[Dictionary] = []
	for index in range(3):
		var base: Node3D = home.get_node_or_null(["WelcomeStep","MiddleEntryStep","LowerEntryStep"][index])
		var tread: Node3D = home.get_node_or_null(["ThresholdTread","MiddleTread","LowerTread"][index])
		if not _check(base is MeshInstance3D and tread is MeshInstance3D, "home %d entry level %d has solid base and tread geometry" % [style,index]):
			continue
		var solid := _measure(base)
		var surface := _measure(tread)
		var top: float = solid.max_y+base.position.y
		var tread_top: float = surface.max_y+tread.position.y
		var front: float = solid.max_z+base.position.z
		var back: float = solid.min_z+base.position.z
		_check(absf(top-float([0.18,0.045,-0.09][index])) < 0.002 and absf(float(solid.min_y)+base.position.y+0.14) < 0.002, "home %d entry level %d has intended descending height and buried base" % [style,index])
		_check(tread_top > top and tread_top < top+0.02 and float(surface.min_y)+tread.position.y <= top, "home %d entry level %d tread touches its supporting base" % [style,index])
		if not levels.is_empty():
			var previous: Dictionary = levels[-1]
			_check(previous.top-tread_top > 0.10 and front > previous.front+0.08 and back <= previous.front, "home %d entry descends outward with connected step bases" % style)
		levels.append({"top":tread_top,"base_top":top,"front":front,"back":back})
	print("CRAFT_ENTRY_LEVELS: ",JSON.stringify({"style":style,"levels":levels}))

func _generated_worlds() -> void:
	var tree := Botany.tree()
	var plant_material: Material = tree.get_node("PlantMesh").mesh.surface_get_material(0)
	tree.free()
	for planet in range(6):
		var world: Node = game.worlds[planet]
		var sphere: MeshInstance3D = world._root.get_node("WalkableSphere")
		_check(sphere.mesh is SphereMesh and is_equal_approx(sphere.mesh.radius,game.RADII[planet]), "planet %d keeps its unchanged walking sphere" % planet)
		_check(world._grass.get_shader_parameter("clover_craft") == (planet == 0), "soft ground regions are enabled only on Clover")
		var colored_vertices := 0
		var colors_valid := true
		var geometry_finite := true
		for mesh_node in world._root.find_children("*","MeshInstance3D",true,false):
			geometry_finite = geometry_finite and mesh_node.transform.is_finite()
			for surface in range(mesh_node.mesh.get_surface_count()):
				if mesh_node.get_active_material(surface) == plant_material:
					var arrays: Array = mesh_node.mesh.surface_get_arrays(surface)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
					colored_vertices += vertices.size()
					colors_valid = colors_valid and colors.size() == vertices.size()
					var distinct := {}
					for index in range(vertices.size()):
						geometry_finite = geometry_finite and vertices[index].is_finite()
						if index < colors.size():
							distinct[colors[index].to_html()] = true
					colors_valid = colors_valid and distinct.size() > 8
		_check(geometry_finite and colors_valid and (colored_vertices > 0 if planet == 0 else colored_vertices == 0), "planet %d batching preserves new Clover botany colors and leaves other-world trees unchanged" % planet)
		var masks_valid := true
		for key in world.anchors:
			var target: Vector3 = world.anchors[key]
			var midpoint := Vector3.UP.slerp(target,0.5).normalized()
			masks_valid = masks_valid and not world.placement_issue(midpoint,0.0).is_empty()
		_check(masks_valid, "planet %d hub-to-anchor route interiors remain protected from placement" % planet)
		for obstacle in world.obstacles:
			_check(obstacle.normal.is_finite() and absf(obstacle.normal.length()-1.0) < 0.001 and float(obstacle.radius) > 0, "planet %d generated solid has a valid collision record" % planet)
		print("CRAFT_WORLD: ",JSON.stringify({"planet":planet,"solids":world.obstacles.size(),"botany_vertices":colored_vertices,"terrain_areas":world._areas.size(),"routes":world._routes.size()}))

func _building_boundaries() -> void:
	var original_planet: int = game.current
	var original_normal: Vector3 = game.normal
	for planet in range(6):
		game.current = planet
		var world: Node = game.worlds[planet]
		for key in (["town_hall","shop","clothes"] if planet == 3 else ["home"]):
			var center: Vector3 = world.anchors[key]
			var piece: Node3D = world._art_piece("building",key)
			var vertices := _measure(piece)
			var conservative: float = world._footprint(piece)
			var size := minf(1.65,1.70/maxf(conservative,0.01))
			var actual_radius := float(vertices.radius)*size
			var obstacle: Dictionary = {}
			for record in world.obstacles:
				if record.normal.is_equal_approx(center):
					obstacle = record
					break
			if not _check(not obstacle.is_empty(), "planet %d %s has a generated building collider" % [planet,key]):
				piece.free()
				continue
			_check(float(obstacle.radius)+0.001 >= actual_radius and float(obstacle.radius) <= 1.701, "planet %d %s collider encloses visible geometry while keeping its reach cap" % [planet,key])
			piece.free()
			var front: Vector3 = world._frame(center).z
			r._position_at((center+front*2.3/game.RADII[planet]).normalized())
			var minimum := INF
			for step in range(90):
				var toward: Vector3 = (center-game.normal*center.dot(game.normal)).normalized()
				var right: Vector3 = game.camera.global_basis.x
				right = (right-game.normal*right.dot(game.normal)).normalized()
				var forward := right.cross(game.normal).normalized()
				var input := Vector2(toward.dot(right),toward.dot(forward))
				var actions := ["move_left","move_right","move_up","move_down"]
				var strengths := [maxf(0,-input.x),maxf(0,input.x),maxf(0,-input.y),maxf(0,input.y)]
				for index in range(4):
					Input.action_release(actions[index])
					if strengths[index] > 0.001:
						Input.action_press(actions[index],strengths[index])
				Input.action_press("run")
				game._process(1.0/60.0)
				minimum = minf(minimum,game.normal.distance_to(center)*game.RADII[planet])
			for action in ["move_left","move_right","move_up","move_down","run"]:
				Input.action_release(action)
			_check(minimum >= actual_radius+0.10 and minimum < 2.4 and r._sphere_ok(), "planet %d %s natural motion stops outside visible building without losing door reach" % [planet,key])
			if planet == 3:
				var before: bool = game.hud.is_panel_open()
				r._key(KEY_E)
				_check(not before and game.hud.is_panel_open(), "Commons %s remains interactable from its collision boundary" % key)
				game.hud.close_panel()
			print("CRAFT_BUILDING_CONTACT: ",JSON.stringify({"planet":planet,"building":key,"visible_radius":actual_radius,"collider_radius":obstacle.radius,"minimum_center_distance":minimum}))
	game.current = original_planet
	r._position_at(original_normal)
	game._update_status()
