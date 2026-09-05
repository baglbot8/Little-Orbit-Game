extends SceneTree
## Actual game renders at three UI sizes; separate from player saves.
var game:Node
var folder := "res://captures/polish"
var source_identity: Dictionary
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	assert("--integration" in OS.get_cmdline_user_args())
	source_identity = _source_identity()
	if "--craft" in OS.get_cmdline_user_args():
		folder = "res://captures/craft"
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	if "--rich-lighting" in OS.get_cmdline_user_args():
		folder = "res://captures/lighting"
		root.use_taa = true
		for child in game.get_children():
			if child is WorldEnvironment:
				child.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
				child.environment.ssao_enabled = true
				child.environment.ssao_radius = 0.8
				child.environment.ssao_intensity = 1.4
				child.environment.ssao_light_affect = 0.3
			if child is DirectionalLight3D:
				child.light_energy *= 0.8
				child.light_angular_distance = 0.45
	await create_timer(0.5).timeout
	game.set_process(false)
	game.hud.toast("")
	DirAccess.make_dir_recursive_absolute(folder)
	game.at_title = true
	game.player.visible = false
	for viewport_size in [Vector2i(1280,800),Vector2i(960,600)]:
		root.size = viewport_size
		game.hud.show_start_menu(false)
		game._update_camera(5)
		await _capture("title_new_%d" % viewport_size.x)
		game.hud.show_start_menu(true)
		await _capture("title_continue_%d" % viewport_size.x)
		game._action("settings")
		await _capture("settings_%d" % viewport_size.x)
		game.hud.close_panel()
	game.at_title = false
	game.player.visible = true
	root.size = Vector2i(1280,800)
	for i in range(4):
		game.current = i
		game.normal = Vector3(0,1,0.35).normalized()
		game.orbit = 0
		game.overview = false
		game._update_player(0)
		game._update_camera(5)
		game._update_status()
		game._update_hint()
		await _capture(["clover","luma","rust","commons"][i])
	var detail_shots: Array = [
		{"name":"clover_patio","planet":0,"n":game.worlds[0]._offset(game.worlds[0]._offset(game.worlds[0].anchors.home,3.9,-0.2),0.0,2.1),"orbit":0.0},
		{"name":"luma_bank","planet":1,"n":Vector3(0.14,1,0.58),"orbit":0.75},
		{"name":"rust_workshop","planet":2,"n":Vector3(-0.12,1,-0.03),"orbit":0.0},
		{"name":"commons_lawn","planet":3,"n":Vector3(0,1,0.27),"orbit":0.0}]
	if "--craft" in OS.get_cmdline_user_args():
		detail_shots.append({"name":"clover_tree","planet":0,"n":game.worlds[0]._offset(Vector3(-0.60,1,0.35).normalized(),0,2.4),"orbit":0.0})
		for planet in [1,2]:
			detail_shots.append({"name":"luma_home" if planet == 1 else "rust_home","planet":planet,"n":game.worlds[planet]._offset(game.worlds[planet].anchors.home,-1.8,3.0),"orbit":0.2})
	for shot in detail_shots:
		game.current = shot.planet
		game.normal = game._resolve_surface(shot.n.normalized())
		game.orbit = shot.orbit
		game.distance = 15
		game.camera_planet = -1
		game._update_player(0)
		game._update_camera(5)
		game._update_status()
		game._update_hint()
		await _capture(shot.name)
	game.distance = 19
	game.orbit = 0
	game.normal = Vector3(0,1,0.35).normalized()
	game.camera_planet = -1
	game.current = 0
	game._update_player(0)
	game.overview = true
	game._update_camera(5)
	game._update_status()
	await _capture("overview")
	game.overview = false
	game._update_camera(5)
	for viewport_size in [Vector2i(1280,800),Vector2i(960,600),Vector2i(1600,1000)]:
		root.size = viewport_size
		await process_frame
		game._town("shop")
		await _capture("shop_%d" % viewport_size.x)
		game.hud._panel_scroll.scroll_vertical = 100000
		await _capture("shop_last_%d" % viewport_size.x)
		game.hud.close_panel()
		game._town("clothes")
		await _capture("wardrobe_%d" % viewport_size.x)
		game.hud.close_panel()
		game._action("journal")
		await _capture("journal_%d" % viewport_size.x)
		game.hud.close_panel()
		game._action("decorate")
		await _capture("bag_%d" % viewport_size.x)
		game.hud.close_panel()
	root.size = Vector2i(1280,800)
	game.current = 1
	game.normal = (game._anchor(1,"neighbor",Vector3.UP)+Vector3(0,0,0.20)).normalized()
	game._update_player(0)
	game._update_status()
	game._talk(0)
	game._update_neighbors(0.2)
	game._update_camera(5)
	await _capture("hello_lumi")
	game.hud.close_panel()
	game.current = 2
	game.normal = (game._anchor(2,"neighbor",Vector3.UP)+Vector3(0,0,0.20)).normalized()
	game._update_player(0)
	game._update_status()
	game._talk(1)
	game._update_neighbors(0.2)
	game._update_camera(5)
	await _capture("hello_bolt")
	game.audio.stop_all()
	await create_timer(0.3).timeout
	game.queue_free()
	await process_frame
	assert(source_identity == _source_identity(), "Source changed during capture; repeat this gallery after the edits settle.")
	var evidence: Dictionary = {"captured_utc":Time.get_datetime_string_from_system(true), "engine":Engine.get_version_info().string, "source_sha256":source_identity, "captures_sha256":{}}
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".png"):
			evidence.captures_sha256[file] = FileAccess.get_sha256(folder+"/"+file)
	var manifest = FileAccess.open(folder+"/manifest.json", FileAccess.WRITE)
	assert(manifest != null)
	manifest.store_string(JSON.stringify(evidence, "\t"))
	manifest.close()
	print("POLISH_GALLERY_COMPLETE")
	quit()

func _source_identity() -> Dictionary:
	var paths: Array[String] = ["res://project.godot", "res://main.tscn", "res://default_bus_layout.tres", "res://assets/orbit_icon.svg", "res://tests/polish_gallery.gd"]
	for file in DirAccess.get_files_at("res://scripts"):
		if file.ends_with(".gd"):
			paths.append("res://scripts/"+file)
	for file in DirAccess.get_files_at("res://assets/icons"):
		if file.ends_with(".png"):
			paths.append("res://assets/icons/"+file)
	paths.sort()
	var identity: Dictionary = {}
	for path in paths:
		identity[path] = FileAccess.get_sha256(path)
	return identity

func _capture(label:String) -> void:
	for frame in range(24):
		await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(folder+"/"+label+".png") == OK)
