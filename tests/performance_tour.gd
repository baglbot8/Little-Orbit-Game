extends SceneTree
## A bounded real-time rendering sample. Movie Maker FPS is not a benchmark.
## Run with --max-fps 60 and -- --integration to avoid player progress IO.
var game: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert("--integration" in OS.get_cmdline_user_args())
	root.size = Vector2i(1280,800)
	var startup := Time.get_ticks_usec()
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	print("PERF_STARTUP_SCENE_MS: ", (Time.get_ticks_usec()-startup)/1000.0)
	if "--perf-title" in OS.get_cmdline_user_args():
		game.at_title = true
		game.player.visible = false
		game.hud.show_start_menu(false)
		await create_timer(3.0).timeout
		game._action("continue")
	await create_timer(2.0).timeout
	for planet in range(4):
		game.current = planet
		game.normal = Vector3(0,1,0.35).normalized()
		game.camera_planet = -1
		game.velocity = Vector3.ZERO
		game._update_player(0)
		game._update_camera(5)
		game._update_status()
		Input.action_press("move_left")
		Input.action_press("run")
		await create_timer(0.5).timeout
		await _sample(game.NAMES[planet], 4.0)
		Input.action_release("move_left")
		Input.action_release("run")
	game._travel(1)
	await _sample("Rocket flight", 5.0)
	game._finish_quit()

func _sample(label: String, seconds: float) -> void:
	var intervals: Array[float] = []
	var ticks := Time.get_ticks_usec()
	var end := ticks + int(seconds*1000000.0)
	var draw_calls := 0
	var objects := 0
	var drawn := Engine.get_frames_drawn()
	while ticks < end:
		await process_frame
		var now := Time.get_ticks_usec()
		var interval := (now-ticks)/1000.0
		intervals.append(interval)
		if interval > 50.0:
			print("PERF_SPIKE: ", JSON.stringify({"scene":label,"interval_ms":interval,"window_focused":root.has_focus(),"window_mode":root.mode,"drawn_frames_since_previous":Engine.get_frames_drawn()-drawn,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0}))
		drawn = Engine.get_frames_drawn()
		ticks = now
		draw_calls = maxi(draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		objects = maxi(objects, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	intervals.sort()
	var total := 0.0
	for interval in intervals:
		total += interval
	print("PERF_STAGE: ",JSON.stringify({"scene":label,"frames":intervals.size(),"mean_ms":total/intervals.size(),"p95_ms":intervals[int((intervals.size()-1)*0.95)],"p99_ms":intervals[int((intervals.size()-1)*0.99)],"max_ms":intervals.back(),"max_draw_calls":draw_calls,"max_render_objects":objects,"static_memory_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0}))
