extends SceneTree
## Save-free comparison of the real Compatibility renderer at the walking camera.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert("--integration" in OS.get_cmdline_user_args())
	root.size = Vector2i(1280, 800)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var environment: Environment
	var lights: Array[DirectionalLight3D] = []
	for child in game.get_children():
		if child is WorldEnvironment:
			environment = child.environment
		elif child is DirectionalLight3D:
			lights.append(child)
	DirAccess.make_dir_recursive_absolute("res://captures/mobile_lighting")
	for variant in ["mobile_final"]:
		if variant == "balanced":
			environment.ambient_light_energy = 0.22
			lights[0].light_energy = 0.52
			lights[1].light_energy = 0.13
		if variant == "gentle":
			environment.ambient_light_energy = 0.17
			lights[0].light_energy = 0.30
			lights[1].light_energy = 0.08
		for planet in [0, 1]:
			game.current = planet
			game.normal = Vector3(0, 1, 0.35).normalized()
			game.camera_planet = -1
			game._update_player(0)
			game._update_status()
			game._update_camera(10)
			game._update_mobile_details()
			for frame in range(12):
				await process_frame
			RenderingServer.force_draw(false)
			assert(root.get_texture().get_image().save_png("res://captures/mobile_lighting/%s_%d.png" % [variant, planet]) == OK)
	game.audio.stop_all()
	await create_timer(0.3).timeout
	game.queue_free()
	await process_frame
	print("WEB_LIGHTING_CAPTURE_COMPLETE")
	quit()
