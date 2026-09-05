class_name TouchControls
extends CanvasLayer
## Only owned fingers are consumed. New fingers reach normal GUI before this layer.
signal action_requested(action: String)
signal camera_drag(delta: Vector2)

const MOVE := ["move_left", "move_right", "move_up", "move_down"]
var run_toggle_mode := true
var _enabled := false
var _blocked := true
var _placing := false
var _flying := false
var _owners: Dictionary = {}
var _pressed: Dictionary = {}
var _run_latched := false
var _stick := Vector2.ZERO
var _center := Vector2.ZERO
var _radius := 62.0
var _unit := 1.0
var _buttons: Dictionary = {}
var _labels: Dictionary = {}
var _surface: Control

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enabled = DisplayServer.is_touchscreen_available() or "--touch-test" in OS.get_cmdline_user_args()
	if "--touch-test" in OS.get_cmdline_user_args():
		Input.emulate_touch_from_mouse = true
	for action in MOVE + ["run"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	_surface = Control.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_surface)
	_surface.draw.connect(_draw_controls)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh()

func set_game_state(blocked: bool, placing: bool, flying: bool) -> void:
	if blocked == _blocked and placing == _placing and flying == _flying:
		return
	release_inputs()
	_blocked = blocked
	_placing = placing
	_flying = flying
	if is_instance_valid(_surface):
		_layout()
		_refresh()

func is_touch_enabled() -> bool:
	return _enabled

func is_touch_active() -> bool:
	return is_touch_enabled()

func get_reserved_height() -> float:
	return 170.0 * _unit

func release_inputs() -> void:
	for action in _pressed:
		Input.action_release(action)
	_pressed.clear()
	_owners.clear()
	_stick = Vector2.ZERO
	_run_latched = false
	if is_instance_valid(_surface):
		_surface.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_inputs()

func _exit_tree() -> void:
	release_inputs()

func _refresh() -> void:
	visible = _enabled and not _blocked and not _flying

func _layout() -> void:
	# Screen transform includes project stretch; web uses CSS px for finger targets.
	var screen_scale := get_viewport().get_screen_transform().get_scale().x
	_unit = 1.0 / maxf(screen_scale, 0.01)
	if OS.has_feature("web"):
		_unit *= float(JavaScriptBridge.eval("window.LittleOrbit ? window.LittleOrbit.pixelRatio : (window.devicePixelRatio || 1)"))
	var bounds := get_viewport().get_visible_rect()
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		var safe := Rect2(DisplayServer.get_display_safe_area())
		if safe.has_area() and OS.has_feature("mobile"):
			var origin := Vector2(DisplayServer.window_get_position())
			bounds = Rect2((safe.position - origin) * _unit, safe.size * _unit).intersection(bounds)
	var compact := bounds.size.x / _unit < 360.0
	_radius = (44.0 if compact else 58.0) * _unit
	_center = Vector2(bounds.position.x + (62.0 if compact else 78.0) * _unit, bounds.end.y - 82.0 * _unit)
	_buttons.clear()
	_labels.clear()
	var rows: Array = [["map", "decorate", "pause"], ["run", "hop", "interact"]]
	if _placing:
		rows = [["map", "decorate", "pause"], ["rotate_item", "remove_item", "confirm_placement"]]
	var labels := {"map":"Map", "decorate":"Bag", "pause":"Pause", "run":"Run", "hop":"Jump", "interact":"Use", "rotate_item":"Rotate", "remove_item":"Refund", "confirm_placement":"Place"}
	for row in range(2):
		for col in range(3):
			var action: String = rows[row][col]
			var pos := Vector2(bounds.end.x - (190.0 - col * 60.0) * _unit, bounds.end.y - (140.0 - row * 64.0) * _unit)
			_buttons[action] = Rect2(pos, Vector2(56, 56) * _unit)
			_labels[action] = labels[action]
	_surface.queue_redraw()

func _draw_controls() -> void:
	var ink := Color("f5efdb")
	var back := Color(0.07, 0.14, 0.19, 0.82)
	_surface.draw_circle(_center, _radius, back)
	_surface.draw_arc(_center, _radius, 0, TAU, 64, Color("93b9aa"), 2.0 * _unit, true)
	_surface.draw_circle(_center + _stick * _radius * 0.65, 23.0 * _unit, Color("d0debf"))
	var font := ThemeDB.fallback_font
	for action in _buttons:
		var rect: Rect2 = _buttons[action]
		var style := StyleBoxFlat.new()
		style.bg_color = Color("44695e") if action == "run" and _run_latched else back
		style.set_corner_radius_all(int(17 * _unit))
		style.set_border_width_all(maxi(1, int(_unit)))
		style.border_color = Color("93b9aa")
		_surface.draw_style_box(style, rect)
		var text: String = _labels[action]
		var size := maxi(12, int(13 * _unit))
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		_surface.draw_string(font, rect.get_center() + Vector2(-width / 2, 5 * _unit), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)

func _input(event: InputEvent) -> void:
	# Once captured, finish this finger even when it crosses an unrelated GUI.
	if event is InputEventScreenTouch and not event.pressed and _owners.has(event.index):
		_finish(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _owners.has(event.index):
		var owner: String = _owners[event.index]
		if owner == "stick":
			_move(event.position)
		elif owner == "camera":
			camera_drag.emit(event.relative / _unit)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch or not event.pressed:
		return
	if not _enabled:
		_enabled = true
		_refresh()
	if not visible:
		return
	var owner := "camera"
	if event.position.distance_to(_center) <= _radius * 1.15:
		owner = "stick"
	else:
		for action in _buttons:
			if _buttons[action].has_point(event.position):
				owner = action
				break
	# One finger per role; never turn a second joystick finger into camera input.
	if owner in _owners.values():
		return
	_owners[event.index] = owner
	get_viewport().set_input_as_handled()
	if owner == "stick":
		_move(event.position)
	elif owner == "run":
		_run_latched = not _run_latched if run_toggle_mode else true
		_set_action("run", 1.0 if _run_latched else 0.0)
		_surface.queue_redraw()
	elif owner != "camera":
		action_requested.emit(owner)

func _finish(index: int) -> void:
	var owner: String = _owners[index]
	_owners.erase(index)
	if owner == "stick":
		_stick = Vector2.ZERO
		for action in MOVE:
			_set_action(action, 0)
	elif owner == "run" and not run_toggle_mode:
		_run_latched = false
		_set_action("run", 0)
	_surface.queue_redraw()

func _move(position: Vector2) -> void:
	_stick = ((position - _center) / _radius).limit_length()
	var v := _stick
	if v.length() < 0.15:
		v = Vector2.ZERO
	else:
		v = v.normalized() * ((v.length() - 0.15) / 0.85)
	_set_action("move_left", maxf(0, -v.x))
	_set_action("move_right", maxf(0, v.x))
	_set_action("move_up", maxf(0, -v.y))
	_set_action("move_down", maxf(0, v.y))
	_surface.queue_redraw()

func _set_action(action: String, strength: float) -> void:
	if strength > 0:
		Input.action_press(action, strength)
		_pressed[action] = true
	elif _pressed.has(action):
		Input.action_release(action)
		_pressed.erase(action)
