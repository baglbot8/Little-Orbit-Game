extends SceneTree
## Bounded arrival-to-conversation regression; no saves or production edits.
## godot --path . --script res://tests/natural_approach.gd -- --integration --natural-approach --natural-visual
## Movement uses Input action strengths with the live camera orientation.
## Simulation is stepped at 1/60; this is not a frame-rate benchmark.

var game: Node
var checks := 0
var failures: Array[String] = []
const STEP := 1.0 / 60.0
const MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "run"]
var qa_size := Vector2i(1280,800)

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, evidence: String) -> bool:
	checks += 1
	if not ok:
		failures.append(evidence)
		printerr("NATURAL_ASSERTION: " + evidence)
	return ok

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--integration" in args or not "--natural-approach" in args:
		printerr("NATURAL_REFUSED: requires --integration --natural-approach before any game/save IO")
		quit(2)
		return
	for forbidden in ["--smoke-test", "--capture", "--gallery", "--reel"]:
		if forbidden in args:
			printerr("NATURAL_REFUSED: automatic game test mode is incompatible: ", forbidden)
			quit(2)
			return
	for arg in args:
		if arg.begins_with("--qa-size="):
			var parts: PackedStringArray = arg.trim_prefix("--qa-size=").split("x")
			if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
				quit(2)
				return
			qa_size = Vector2i(int(parts[0]),int(parts[1]))
			if not qa_size in [Vector2i(1280,800),Vector2i(844,390),Vector2i(390,844)]:
				quit(2)
				return
	root.size = qa_size
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	if not _check(game.test_mode and not game.at_title and game.current == 0, "fresh save-free integration starts on Clover"):
		await _finish()
		return
	_check(Vector2i(root.get_visible_rect().size) == qa_size, "native viewport matches requested size " + str(qa_size))
	print("NATURAL_ENV: ", JSON.stringify({"display":DisplayServer.get_name(), "viewport":str(root.get_visible_rect().size), "step_seconds":STEP, "test_mode":game.test_mode}))
	# Focused final-UI recheck: four full dialogues, without repeating the run tour.
	for sprint in ([false] if "--dialogue-framing-only" in args else [false,true]):
		for who in range(4):
			if not await _arrive([1,2,4,5][who]):
				await _finish()
				return
			await _approach_and_talk(who,sprint)
	if "--placement-hint" in args and qa_size == Vector2i(844,390):
		await _placement_hint()
	await _finish()

func _key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func _button(prefix: String) -> Button:
	for node in game.hud.find_children("*","Button",true,false):
		if node.is_visible_in_tree() and not node.disabled and node.text.begins_with(prefix):
			return node
	return null

func _click(button: Button) -> bool:
	if not _check(button != null, "requested action has an enabled real button"):
		return false
	var in_scroll: bool = game.hud._panel_scroll.is_ancestor_of(button)
	if in_scroll:
		game.hud._panel_scroll.ensure_control_visible(button)
	await process_frame
	await process_frame
	var point := button.get_global_rect().get_center()
	if not _check(root.get_visible_rect().has_point(point) and (not in_scroll or game.hud._panel_scroll.get_global_rect().has_point(point)), "action pointer is inside the viewport and its visible container"):
		return false
	if "--dialogue-framing-only" in OS.get_cmdline_user_args():
		# This focused capture validates full-text framing, not native pointer
		# delivery. Use the actual button signal for map and reveal activation.
		button.pressed.emit()
		await process_frame
		await process_frame
		return true
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	return true

func _arrive(planet: int) -> bool:
	_release_movement()
	await _key(KEY_M)
	if not _check(game.hud.is_panel_open(), "routed M opens map from the prior world"):
		return false
	await _click(_button("Visit " + ("Commons" if planet == 3 else game.NAMES[planet])))
	if not _check(game.flight and game.flight_target == planet, "actual map destination click starts normal flight"):
		return false
	var frames := 0
	var finite := true
	while game.flight and frames < 330:
		game._process(STEP)
		finite = finite and game.camera.global_transform.is_finite()
		frames += 1
		if frames % 30 == 0:
			await process_frame
	if not _check(not game.flight and game.current == planet and game.player.visible and finite, "five-second flight lands normally with finite camera"):
		return false
	for frame in range(60):
		game._process(STEP)
	var spawn := Vector3(0,1,0.35).normalized()
	return _check(game.normal.is_equal_approx(spawn) and game.velocity.is_zero_approx(), "approach starts at the unmodified ordinary arrival position")

func _release_movement() -> void:
	for action in MOVE_ACTIONS:
		Input.action_release(action)

func _steer(target: Vector3, sprint: bool) -> void:
	var up: Vector3 = game.normal
	var toward := (target-up*target.dot(up)).normalized()
	var right: Vector3 = game.camera.global_basis.x
	right = (right-up*right.dot(up)).normalized()
	var forward := right.cross(up).normalized()
	var direction := Vector2(toward.dot(right),toward.dot(forward))
	var strengths := [maxf(0,-direction.x),maxf(0,direction.x),maxf(0,-direction.y),maxf(0,direction.y)]
	for index in range(4):
		Input.action_release(MOVE_ACTIONS[index])
		if strengths[index] > 0.001:
			Input.action_press(MOVE_ACTIONS[index],strengths[index])
	if sprint:
		Input.action_press("run")
	else:
		Input.action_release("run")

func _gap(who: int) -> float:
	var target: Vector3 = game.worlds[[1,2,4,5][who]].anchors.neighbor
	return game.normal.distance_to(target)*float(game.RADII[[1,2,4,5][who]])

func _approach_and_talk(who: int, sprint: bool) -> void:
	var label: String = ["Lumi","Bolt","Pip","Miso"][who] + (" running" if sprint else " walking")
	var target: Vector3 = game.worlds[[1,2,4,5][who]].anchors.neighbor
	var start: Vector3 = game.normal
	var initial_gap := _gap(who)
	var minimum_gap := initial_gap
	var maximum_speed := 0.0
	var finite := true
	var steps := 0
	while _gap(who) > 1.25 and steps < 720:
		_steer(target,sprint)
		game._process(STEP)
		steps += 1
		minimum_gap = minf(minimum_gap,_gap(who))
		maximum_speed = maxf(maximum_speed,game.velocity.length())
		finite = finite and game.normal.is_finite() and game.player.global_transform.is_finite() and game.camera.global_transform.is_finite()
		if steps % 12 == 0:
			await process_frame
	print("NATURAL_APPROACH: ", JSON.stringify({"case":label,"initial_gap":initial_gap,"final_gap":_gap(who),"minimum_gap":minimum_gap,"seconds":steps*STEP,"max_speed":maximum_speed,"run_active":game.running,"input":str(Input.get_vector("move_left","move_right","move_up","move_down"))}))
	if not _check(_gap(who) <= 1.25 and steps < 720 and start.distance_to(game.normal)*game.RADII[[1,2,4,5][who]] > 1.0, label+": steering from arrival reaches the neighbor without teleporting"):
		_release_movement()
		return
	_check(finite and minimum_gap >= 0.55 and absf(game.normal.length()-1.0) < 0.001, label+": approach remains finite, on the sphere and outside the NPC footprint")
	_check(game.running == sprint and maximum_speed > (4.0 if sprint else 2.5), label+": intended walking/running state is actually exercised")
	var talks_before: int = game.talk_counts[who]
	await _key(KEY_E)
	game._process(STEP)
	if not _check(game.hud.is_panel_open() and game.conversation and game.talk_counts[who] == talks_before+1 and _labels().contains(["Lumi","Bolt","Pip","Miso"][who]), label+": actual E routing opens the correct neighbor conversation once"):
		_release_movement()
		return
	var frozen: Vector3 = game.normal
	var modal_gap := _gap(who)
	# Keep directional input held, and explicitly hold Run throughout the modal.
	Input.action_press("run")
	var stopped := true
	for frame in range(120):
		game._process(STEP)
		stopped = stopped and not game.running and game.velocity.is_zero_approx() and game.normal.is_equal_approx(frozen)
		finite = finite and game.camera.global_transform.is_finite() and absf(game.camera.global_basis.determinant()-1.0) < 0.001
		if frame % 30 == 0:
			await process_frame
	_check(stopped, label+": two seconds of held movement plus Run cannot move behind the modal")
	_check(finite and modal_gap >= 0.55 and is_equal_approx(_gap(who),modal_gap), label+": conversation camera stays finite and player/NPC remain separated")
	# Deterministic simulation does not advance real-time HUD typing. Reveal
	# through its real choice button before measuring the FULL dialogue layout.
	if game.hud.get("_typing") == true:
		var reveal: Button = null
		for prefix in ["I'll find it!", "See you soon", "Thank you!", "Another little favor?", "I'd love to!"]:
			if _button(prefix) != null:
				reveal = _button(prefix)
				break
		await _click(reveal)
		await process_frame
		await process_frame
	_check(game.hud.is_panel_open() and game.hud.get("_typing") == false and game.talk_counts[who] == talks_before+1, label+": first choice click reveals full dialogue without another interaction")
	# Let adaptive camera framing converge against the final revealed bubble.
	for frame in range(60):
		game._process(STEP)
		if frame % 15 == 0:
			await process_frame
	var player_point: Vector3 = game.player.global_position + game.normal*0.8
	var neighbor: Node3D = game.neighbors[who]
	var npc_point := neighbor.global_position + neighbor.global_basis.y.normalized()*0.65
	var player_screen: Vector2 = game.camera.unproject_position(player_point)
	var npc_screen: Vector2 = game.camera.unproject_position(npc_point)
	var view := root.get_visible_rect()
	var panel: Rect2 = game.hud._panel.get_global_rect()
	_check(not game.camera.is_position_behind(player_point) and not game.camera.is_position_behind(npc_point) and view.has_point(player_screen) and view.has_point(npc_screen) and player_screen.distance_to(npc_screen) > 30, label+": both projected character centers are in view and distinct")
	print("NATURAL_FRAMING: ",JSON.stringify({"case":label,"player_screen":str(player_screen),"npc_screen":str(npc_screen),"separation_px":player_screen.distance_to(npc_screen),"player_center_covered_by_panel":panel.has_point(player_screen),"npc_center_covered_by_panel":panel.has_point(npc_screen)}))
	_check(not panel.has_point(player_screen) and not panel.has_point(npc_screen), label+": full conversation panel does not cover either character center at " + str(qa_size))
	await _key(KEY_E)
	game._process(STEP)
	_check(game.talk_counts[who] == talks_before+1 and game.hud.is_panel_open(), label+": E inside conversation cannot start a duplicate interaction")
	await _capture(["luma","rust","pebble","honey"][who],sprint)
	_release_movement()
	await _key(KEY_ESCAPE)
	game._process(STEP)
	_check(not game.hud.is_panel_open() and not game.conversation and game.camera.global_transform.is_finite(), label+": Escape returns cleanly to the world")

func _labels() -> String:
	var value := ""
	for label in game.hud.find_children("*","Label",true,false):
		if label.is_visible_in_tree():
			value += label.text+"\n"
	return value

func _placement_hint() -> void:
	if not await _arrive(0):
		return
	game._start_placement(0)
	var target := Vector3.ZERO
	for index in range(180):
		var y := 1.0-2.0*(index+0.5)/180.0
		var radius := sqrt(1.0-y*y)
		var candidate := Vector3(cos(index*2.399963)*radius,y,sin(index*2.399963)*radius)
		if game._placement_issue(candidate).is_empty():
			target = candidate
			break
	if _check(target != Vector3.ZERO, "placement hint fixture has clear Clover ground"):
		var tangent := target.cross(Vector3.UP).normalized()
		var angle := atan(1.25/float(game.RADII[0]))
		game.normal = target*cos(angle)-tangent*sin(angle)
		game.facing = target*sin(angle)+tangent*cos(angle)
		game.velocity = Vector3.ZERO
		game._update_player(0)
		game._update_camera(5)
		game._process(STEP)
		await process_frame
		await process_frame
		_check(game.selected == 0 and is_instance_valid(game.preview) and _labels().contains("Tap Place or Rotate"), "landscape touch placement shows the active hint")
		await _capture("clover-placement-hint",false)
	game._cancel_placement()

func _capture(planet: String, sprint: bool) -> void:
	if not "--natural-visual" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var frame := root.get_texture().get_image()
	var path := "/tmp/little-orbit-natural-%d-%dx%d-%s-%s.png" % [OS.get_process_id(),qa_size.x,qa_size.y,planet,"run" if sprint else "walk"]
	_check(frame != null and frame.get_size() == qa_size and frame.save_png(path) == OK, "save native conversation evidence: "+path)
	print("NATURAL_CAPTURE: ",path)

func _finish() -> void:
	_release_movement()
	if is_instance_valid(game):
		game.audio.stop_all()
		await create_timer(0.3).timeout
		var reference: WeakRef = weakref(game)
		game.queue_free()
		await process_frame
		await process_frame
		_check(reference.get_ref() == null, "test game is freed after mixer drain")
	print("NATURAL_APPROACH_RESULT: %d checks, %d failures" % [checks,failures.size()])
	for evidence in failures:
		printerr("NATURAL_EVIDENCE: ",evidence)
	quit(0 if failures.is_empty() else 1)
