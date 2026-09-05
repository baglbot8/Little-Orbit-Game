extends SceneTree
## Renders the actual placeable models for the shop and decorating bag.
const Art = preload("res://scripts/art.gd")
const Catalog = preload("res://scripts/catalog.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(320,280)
	# A SubViewport preserves alpha independently of the desktop window surface.
	var viewport = SubViewport.new()
	viewport.size = Vector2i(320,280)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage = Node3D.new()
	viewport.add_child(stage)
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0,0,0,0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b7d4e6")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 0.4
	env.ssao_intensity = 1.2
	environment.environment = env
	stage.add_child(environment)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-35,0)
	light.light_color = Color("fff2d5")
	light.light_energy = 0.75
	light.shadow_enabled = true
	stage.add_child(light)
	var camera = Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	DirAccess.make_dir_recursive_absolute("res://assets/icons")
	for kind in ([] if "--neighbors-only" in OS.get_cmdline_user_args() else range(Catalog.NAMES.size())):
		var model = Art.decoration(kind)
		stage.add_child(model)
		var bounds = AABB()
		var first = true
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			var box = mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var center = bounds.get_center()
		camera.position = center+Vector3(2.8,2.3,4.5)
		camera.look_at(center)
		var projected_min = Vector2(INF,INF)
		var projected_max = Vector2(-INF,-INF)
		for corner in range(8):
			var point = bounds.get_endpoint(corner)-center
			var projected = Vector2(point.dot(camera.global_basis.x),point.dot(camera.global_basis.y))
			projected_min = projected_min.min(projected)
			projected_max = projected_max.max(projected)
		var span = projected_max-projected_min
		camera.size = maxf(span.y,span.x/1.142857)*1.15
		for frame in range(24):
			await process_frame
		RenderingServer.force_draw(false)
		var error = viewport.get_texture().get_image().save_png("res://assets/icons/decor_%02d.png" % kind)
		assert(error == OK)
		model.queue_free()
		await process_frame
	for suit in ([] if "--neighbors-only" in OS.get_cmdline_user_args() else range(Catalog.SUIT_NAMES.size())):
		var model = Art.astronaut()
		stage.add_child(model)
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			if mesh.get_meta("suit_accent",false):
				mesh.material_override = Art._material(Catalog.SUIT_COLORS[suit])
		camera.position = Vector3(0.8,1.1,3.7)
		camera.look_at(Vector3(0,0.53,0))
		camera.size = 1.28
		for frame in range(24):
			await process_frame
		RenderingServer.force_draw(false)
		assert(viewport.get_texture().get_image().save_png("res://assets/icons/suit_%02d.png" % suit) == OK)
		model.queue_free()
		await process_frame
	for who in range(4):
		var model = Art.neighbor(who)
		stage.add_child(model)
		camera.position = Vector3(0.18,1.0,3.7)
		camera.look_at(Vector3(0,0.72,0))
		camera.size = 0.84
		for frame in range(24):
			await process_frame
		RenderingServer.force_draw(false)
		assert(viewport.get_texture().get_image().save_png("res://assets/icons/neighbor_%02d.png" % who) == OK)
		model.queue_free()
		await process_frame
	print("CATALOG_RENDERED: ",Catalog.NAMES.size()," actual decoration models")
	viewport.queue_free()
	await process_frame
	quit()
