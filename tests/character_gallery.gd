extends SceneTree
## Actual Godot character renders; no player data or scene state is loaded.
var stage: Node3D
var models: Array[Node3D] = []
var motions: Array = []
var label: String = "after"
var clock_time := 0.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1400,900)
	stage = Node3D.new()
	root.add_child(stage)
	var old = "--before" in OS.get_cmdline_user_args()
	label = "before" if old else "after"
	var art = load("/tmp/little_orbit_art_before.gd") if old else load("res://scripts/art.gd")
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("152339")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bdd4ed")
	env.ambient_light_energy = 0.40
	environment.environment = env
	stage.add_child(environment)
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35,-30,0)
	key.light_color = Color("fff1da")
	key.light_energy = 0.85
	key.shadow_enabled = true
	stage.add_child(key)
	var rim = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15,145,0)
	rim.light_color = Color("9acbdf")
	rim.light_energy = 0.4
	stage.add_child(rim)
	for i in range(3):
		var model:Node3D = [art.astronaut,art.alien,art.robot][i].call()
		stage.add_child(model)
		model.position = Vector3((i-1)*1.7,0,0)
		model.rotation.y = -0.14
		models.append(model)
		var plinth = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		mesh.top_radius = 0.59
		mesh.bottom_radius = 0.59
		mesh.height = 0.10
		mesh.radial_segments = 64
		plinth.mesh = mesh
		plinth.position = Vector3((i-1)*1.7,-0.06,0)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = [Color("eeae92"),Color("bca4d9"),Color("86bbb9")][i]
		plinth.material_override = mat
		stage.add_child(plinth)
	var camera = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0,1.55,6.5)
	camera.look_at(Vector3(0,0.54,0))
	camera.fov = 38
	camera.current = true
	var ui = CanvasLayer.new()
	stage.add_child(ui)
	var title = Label.new()
	title.text = "LITTLE ORBIT  /  THE NEIGHBORHOOD"
	title.position = Vector2(68,55)
	title.add_theme_font_size_override("font_size",20)
	title.add_theme_color_override("font_color",Color("e9e3d5"))
	ui.add_child(title)
	for i in range(3):
		var name_label = Label.new()
		name_label.text = ["YOU  ·  THE EXPLORER","LUMI  ·  THE GARDENER","BOLT  ·  THE TINKERER"][i]
		name_label.position = Vector2(120+i*420,740)
		name_label.size.x = 320
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size",17)
		name_label.add_theme_color_override("font_color",Color("efe9db"))
		ui.add_child(name_label)
	if "--motion" in OS.get_cmdline_user_args():
		await _motion_demo(title)
		stage.queue_free()
		await process_frame
		quit()
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/characters_"+label+".png")
	print("CHARACTER_CAPTURE: "+label)
	stage.queue_free()
	await process_frame
	quit()

func _motion_demo(title:Label) -> void:
	var explorer = load("res://scripts/character_motion.gd").new()
	explorer.setup(models[0])
	var neighbor_controllers:Array = []
	for i in range(2):
		var controller = load("res://scripts/neighbor_motion.gd").new()
		controller.setup(models[i+1],i)
		neighbor_controllers.append(controller)
	DirAccess.make_dir_recursive_absolute("res://captures/character_motion")
	for frame in range(420):
		var t = frame/60.0
		var moving = t < 4
		var run_amount = 1.0 if t >= 2.0 and t < 4.0 else 0.0
		var airborne = t>=4.0 and t<4.8
		title.text = "LITTLE ORBIT  /  " + ("WALK" if t<2 else "SHIFT · RUN" if t<4 else "HOP" if t<4.8 else "A LITTLE HELLO")
		explorer.animate(t,moving,airborne,1.0/60.0,run_amount)
		models[0].position.y = explorer.bob + (sin((t-4.0)/0.8*PI)*0.25 if airborne else 0.0)
		models[0].rotation.x = explorer.lean
		models[0].rotation.z = explorer.sway
		for controller in neighbor_controllers:
			if frame == 300:
				controller.greet()
			controller.animate(t,1.0/60.0,t>=5)
		await process_frame
		if frame in [30,90,132,150,180,210,270,320,360,390]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://captures/character_motion/frame_%03d.png" % frame)
