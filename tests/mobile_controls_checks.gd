extends SceneTree
const Touch = preload("res://scripts/touch_controls.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func finger(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	return event

func _run() -> void:
	var touch := Touch.new()
	root.add_child(touch)
	await process_frame
	check(touch.is_touch_enabled(), "--touch-test enables touch")
	check(not touch.visible, "blocked by default")
	touch.set_game_state(false, false, false)
	var center: Vector2 = touch._center
	touch._unhandled_input(finger(0, center + Vector2(touch._radius, 0), true))
	check(Input.is_action_pressed("move_right"), "joystick presses right")
	touch._unhandled_input(finger(1, Vector2(250, 30), true))
	check(touch._owners.get(1) == "camera", "second finger can own camera independently")
	touch._input(finger(1, Vector2(250, 30), false))
	check(Input.is_action_pressed("move_right"), "camera release preserves movement")
	touch._unhandled_input(finger(2, touch._buttons["run"].get_center(), true))
	touch._input(finger(2, Vector2.ZERO, false))
	check(Input.is_action_pressed("run"), "run latch survives button release")
	touch.set_game_state(false, false, false)
	check(Input.is_action_pressed("move_right"), "unchanged state must not cancel movement")
	touch.set_game_state(true, false, false)
	check(not touch.visible and touch._owners.is_empty(), "modal clears fingers and hides")
	check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("run"), "modal releases both movement and run")
	check(touch.is_touch_enabled(), "menus do not change device capability")
	touch.set_game_state(false, true, false)
	check(touch._buttons.has("confirm_placement") and not touch._buttons.has("hop"), "placement actions replace gameplay row")
	touch.set_game_state(false, false, false)
	touch.run_toggle_mode = false
	touch._unhandled_input(finger(3, touch._buttons["run"].get_center(), true))
	check(Input.is_action_pressed("run"), "hold mode presses run")
	touch._input(finger(3, Vector2.ZERO, false))
	check(not Input.is_action_pressed("run"), "hold mode releases outside button")
	touch._unhandled_input(finger(4, center + Vector2(0, -touch._radius), true))
	touch._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not Input.is_action_pressed("move_up") and touch._owners.is_empty(), "focus loss releases movement")
	touch.set_game_state(false, false, true)
	check(not touch.visible, "flight hides controls")
	# Portrait/landscape target layout must avoid overlapping joystick and buttons.
	for size in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(320, 568)]:
		root.size = size
		touch._layout()
		var stick_right: float = touch._center.x + touch._radius * 1.15
		check(stick_right < touch._buttons["run"].position.x, "joystick/action hit regions overlap at " + str(size))
		for rect in touch._buttons.values():
			check(Rect2(Vector2.ZERO, Vector2(size)).encloses(rect), "button outside viewport")
	# Exercise actual event routing: an unrelated GUI control gets first refusal.
	touch.set_game_state(false, false, false)
	var ui := Control.new()
	ui.position = Vector2(180, 20)
	ui.size = Vector2(100, 80)
	ui.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.gui_input.connect(func(_event: InputEvent): ui.accept_event())
	root.add_child(ui)
	await process_frame
	Input.parse_input_event(finger(7, Vector2(220, 50), true))
	await process_frame
	check(not touch._owners.has(7), "unrelated GUI touch must not become camera drag")
	Input.parse_input_event(finger(7, Vector2(220, 50), false))
	ui.queue_free()
	touch.queue_free()
	await process_frame
	print("MOBILE_CONTROLS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)
