extends SceneTree
## Run only after parent QA-ready: godot --path . --script tests/mobile_visual_gallery.gd -- --integration
## Optional --motion-only or --stills-only avoids duplicate tours. No player saves.
## Native viewport evidence; this does not certify Safari/browser behavior.
var game: Node
var folder := "res://captures/mobile_visual"
var identity: Dictionary
var evidence: Dictionary = {}
var captured: Dictionary = {}
var motion_rows: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not "--integration" in OS.get_cmdline_user_args():
		push_error("MOBILE_VISUAL: --integration is required to isolate player saves.")
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("MOBILE_VISUAL: use an actual renderer, not headless.")
		quit(2)
		return
	identity = _source_identity()
	if "--ui-recheck" in OS.get_cmdline_user_args():
		folder = "res://captures/mobile_visual_ui_recheck"
	if "--camera-recheck" in OS.get_cmdline_user_args():
		folder = "res://captures/mobile_visual_camera_final"
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	game.set_process(false)
	assert(game.test_mode)
	assert(game.worlds.size() == 6 and game.neighbors.size() == 4)
	DirAccess.make_dir_recursive_absolute(folder)
	if "--camera-recheck" in OS.get_cmdline_user_args():
		for dimensions in [Vector2i(844,390), Vector2i(390,844)]:
			await _camera_stills(dimensions)
	elif not "--motion-only" in OS.get_cmdline_user_args():
		for dimensions in [Vector2i(1280,800), Vector2i(844,390), Vector2i(390,844)]:
			await _stills(dimensions)
	if not "--stills-only" in OS.get_cmdline_user_args() and not "--ui-recheck" in OS.get_cmdline_user_args() and not "--camera-recheck" in OS.get_cmdline_user_args():
		await _motion_sequence()
	game.audio.stop_all()
	game.touch_controls.release_inputs()
	game.queue_free()
	await process_frame
	var unchanged := identity == _source_identity()
	var manifest := {"captured_utc":Time.get_datetime_string_from_system(true),
		"engine":Engine.get_version_info().string, "renderer":RenderingServer.get_current_rendering_method(),
		"source_unchanged":unchanged, "source_sha256":identity,
		"captures_sha256":captured, "views":evidence,
		"motion":{"fps":30,"frames":motion_rows,"method":"Input actions drive full main._process at fixed 1/30 s; every frame rendered. Not wall-clock performance evidence."},
		"scope":"Native actual-render viewport simulation; mobile Safari remains separate browser/device QA."}
	var out := FileAccess.open(folder + "/manifest.json", FileAccess.WRITE)
	assert(out != null)
	out.store_string(JSON.stringify(manifest, "\t"))
	out.close()
	if not unchanged:
		push_error("Source changed during gallery; evidence invalid, repeat after freeze.")
		quit(3)
		return
	print("MOBILE_VISUAL_GALLERY_COMPLETE")
	quit()

func _viewport(dimensions: Vector2i) -> void:
	_close()
	root.size = dimensions
	await process_frame
	assert(root.size == dimensions, "Window manager constrained requested viewport.")
	# Explicit touch fixture: the real production overlay and HUD use these values.
	game.touch_controls.release_inputs()
	game.touch_controls.set("_enabled", dimensions.x < 1000)
	game.hud.set_touch_controls_active(dimensions.x < 1000)
	game._sync_touch()

func _close() -> void:
	game.hud.close_panel()
	game.conversation = false
	game.at_title = false
	game.player.visible = true
	game._cancel_placement()
	game.hud.toast("")
	game._sync_touch()

func _world(index: int, n: Vector3 = Vector3(0,1,0.35)) -> void:
	_close()
	game.current = index
	game.normal = game._resolve_surface(n.normalized())
	game.velocity = Vector3.ZERO
	game.orbit = 0.0
	game.pitch = 0.0
	game.distance = 19.0
	game.overview = false
	game.camera_planet = -1
	game._update_player(0)
	game._update_status()
	game._update_mobile_details()
	game._update_hint()
	game._update_camera(5)
	game._sync_touch()

func _stills(dimensions: Vector2i) -> void:
	await _viewport(dimensions)
	var suffix := "_%dx%d" % [dimensions.x, dimensions.y]
	_world(0)
	game.at_title = true
	game.player.visible = false
	game.hud.show_start_menu(false)
	game._update_camera(5)
	await _capture("title_new" + suffix)
	game._action("settings")
	await _capture("settings" + suffix)
	await _scroll_end("settings_end" + suffix)
	for planet in range(1 if "--ui-recheck" in OS.get_cmdline_user_args() else 6):
		_world(planet)
		await _capture("world_%d_%s" % [planet, game.NAMES[planet].to_lower().replace(" ", "_")] + suffix)
	_world(0)
	game._action("map")
	await _capture("map" + suffix)
	await _scroll_end("map_end" + suffix)
	for who in range(4):
		var planet: int = game.NEIGHBOR_PLANETS[who]
		var anchor: Vector3 = game._anchor(planet, "neighbor", Vector3.UP)
		_world(planet, (anchor + Vector3(0,0,0.20)).normalized())
		# Resolve placement before talking; never place explorer on the NPC anchor.
		game._talk(who)
		game._update_neighbors(0.2)
		game._update_camera(5)
		await _capture("dialog_%d_%s" % [who, game.NEIGHBOR_NAMES[who].to_lower()] + suffix)
		await _scroll_end("dialog_%d_end" % who + suffix)
	_world(0)
	game._town("shop")
	await _capture("shop" + suffix)
	await _scroll_end("shop_end" + suffix)
	_close()
	game._action("journal")
	await _capture("journal" + suffix)
	await _scroll_end("journal_end" + suffix)
	_world(0, Vector3(0,1,0.65))
	game._start_placement(0)
	game.hud.toast("")
	game._update_preview()
	game._update_hint()
	await _capture("placement" + suffix)
	_close()

func _scroll_end(label: String) -> void:
	var scroll: ScrollContainer = game.hud.get("_panel_scroll")
	if is_instance_valid(scroll):
		scroll.scroll_vertical = 100000
		await _capture(label)

func _camera_stills(dimensions: Vector2i) -> void:
	await _viewport(dimensions)
	var suffix := "_%dx%d" % [dimensions.x, dimensions.y]
	for who in range(4):
		var planet: int = game.NEIGHBOR_PLANETS[who]
		var anchor: Vector3 = game._anchor(planet, "neighbor", Vector3.UP)
		_world(planet, (anchor + Vector3(0,0,0.20)).normalized())
		game._talk(who)
		game._update_neighbors(0.2)
		await _capture("dialog_%d_%s" % [who, game.NEIGHBOR_NAMES[who].to_lower()] + suffix)
	if dimensions.x == 844:
		_world(0, Vector3(0,1,0.65))
		game._start_placement(0)
		game.hud.toast("")
		game._update_preview()
		game._update_hint()
		await _capture("placement" + suffix)
	_close()

func _capture(label: String) -> void:
	game._sync_touch()
	for frame in range(18):
		await process_frame
	if label.begins_with("dialog_"):
		game.hud._reveal_dialogue()
		for frame in range(8):
			await process_frame
	# Main is paused for stills; refresh its camera against the settled UI rect.
	game._update_camera(5)
	RenderingServer.force_draw(false)
	_save_frame(label + ".png")
	var panel: Control = game.hud.get("_panel")
	evidence[label] = {"viewport":[root.size.x,root.size.y],
		"touch_visible":game.touch_controls.visible,
		"panel_rect":str(panel.get_global_rect()) if is_instance_valid(panel) else "",
		"planet":game.current, "placement_issue":game._placement_issue(game._placement_normal()) if game.selected >= 0 else ""}

func _save_frame(file: String) -> void:
	var shot := root.get_texture().get_image()
	assert(shot.get_size() == root.size)
	assert(shot.save_png(folder + "/" + file) == OK)
	captured[file] = FileAccess.get_sha256(folder + "/" + file)

func _motion_sequence() -> void:
	await _viewport(Vector2i(844,390))
	_world(0, Vector3(0,1,0.72))
	game.distance = 15.0
	game._update_camera(5)
	DirAccess.make_dir_recursive_absolute(folder + "/run")
	# Six continuous seconds: idle, walk, run, turn, walk, stop. Full locomotion,
	# collision, camera and animation execute; no manually assigned limb poses.
	for frame in range(180):
		if frame == 15:
			Input.action_press("move_right")
		if frame == 45:
			Input.action_press("run")
		if frame == 90:
			Input.action_release("move_right")
			Input.action_press("move_down")
		if frame == 120:
			Input.action_release("run")
		if frame == 150:
			Input.action_release("move_down")
		game._process(1.0 / 30.0)
		await process_frame
		RenderingServer.force_draw(false)
		_save_frame("run/frame_%04d.png" % frame)
		motion_rows.append({"frame":frame,"time":frame / 30.0,
			"speed":game.velocity.length(),"run_amount":game.run_amount,
			"position":str(game.player.global_position),"bob":game.motion.bob,
			"lean":game.motion.lean,"sway":game.motion.sway})
	for action in ["move_right", "move_down", "run"]:
		Input.action_release(action)

func _source_identity() -> Dictionary:
	var paths: Array[String] = ["res://project.godot", "res://main.tscn", "res://default_bus_layout.tres", "res://tests/mobile_visual_gallery.gd"]
	for directory in ["res://scripts", "res://assets/icons", "res://assets/ui", "res://assets/ui/fonts"]:
		if not DirAccess.dir_exists_absolute(directory):
			continue
		for file in DirAccess.get_files_at(directory):
			if not file.ends_with(".import") and not file.ends_with(".uid"):
				paths.append(directory + "/" + file)
	paths.sort()
	var result: Dictionary = {}
	for path in paths:
		result[path] = FileAccess.get_sha256(path)
	return result
