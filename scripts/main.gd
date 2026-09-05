extends Node3D

const Art = preload("res://scripts/art.gd")
const World = preload("res://scripts/world.gd")
const HUD = preload("res://scripts/hud.gd")
const Sound = preload("res://scripts/audio.gd")
const Motion = preload("res://scripts/character_motion.gd")
const NeighborMotionController = preload("res://scripts/neighbor_motion.gd")
const Atmosphere = preload("res://scripts/atmosphere.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Neighbourhood = preload("res://scripts/neighborhood.gd")
const Touch = preload("res://scripts/touch_controls.gd")
const NAMES = ["Clover", "Luma", "Rust", "The Commons", "Pebble", "Honey"]
const SUBTITLES = ["Your own little corner of the cosmos", "Lumi's garden of curious things", "Bolt's wonderfully wonky workshop", "Good things happen together", "Pip's outpost of small discoveries", "Something lovely is baking at Miso's"]
const NEIGHBOR_NAMES = ["Lumi", "Bolt", "Pip", "Miso"]
const NEIGHBOR_PLANETS = [1, 2, 4, 5]
const ITEMS = Catalog.NAMES
const CENTERS = [Vector3.ZERO, Vector3(-36, 7, -38), Vector3(38, -3, -43), Vector3(4, 20, -83), Vector3(-52, 18, 15), Vector3(49, 12, 16)]
const RADII = [8.0, 7.5, 7.5, 11.0, 7.5, 7.5]
const WALK_SPEED := 3.3
const RUN_SPEED := 5.5
const SAVE_PATH = "user://orbit_save.json"
var worlds: Array = []
var player: Node3D
var avatar: Node3D
var motion: RefCounted
var camera: Camera3D
var hud: CanvasLayer
var audio: Node
var atmosphere: Node3D
var current := 0
var normal := Vector3(0, 1, 0.35).normalized()
var facing := Vector3.BACK
var orbit := 0.0
var pitch := 0.0
var distance := 19.0
var overview := false
var camera_north := Vector3.BACK
var camera_up := Vector3.UP
var camera_planet := -1
var velocity := Vector3.ZERO
var hop := 0.0
var hop_speed := 0.0
var elapsed := 0.0
var walking := false
var running := false
var run_amount := 0.0
var flight := false
var flight_time := 0.0
var flight_from := Vector3.ZERO
var flight_to := Vector3.ZERO
var flight_origin := 0
var conversation_focus := Vector3.ZERO
var conversation := false
var conversation_back := Vector3.BACK
var flight_target := 0
var ship: Node3D
var stars := 30
var inventory: Array = [2, 1, 1, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var favors: Array = [0, 0, 0, 0]
var friendship: Array = [0, 0, 0, 0]
var cargo: Array = [false, false, false, false]
var quest_round: Array = [0, 0, 0, 0]
var quest_progress: Array = [0, 0, 0, 0]
var collected_bits: Array = [0, 0, 0, 0]
var talk_counts: Array = [0, 0, 0, 0]
var wishes := 0
var placed: Array = []
var placed_nodes: Array = []
var pickups: Array = []
var neighbors: Array = []
var neighbor_motions: Array = []
var preview: Node3D
var preview_material: StandardMaterial3D
var selected := -1
var placement_angle := 0.0
var last_step := 0.0
var suit := 0
var muted := false
var save_timer := 0.0
var screenshot_test := false
var test_mode := false
var closing := false
var at_title := false
var save_available := false
var save_error_shown := false
var music_volume := 0.18
var effects_volume := 0.24
var touch_controls: CanvasLayer
var mobile_profile := OS.has_feature("web") or OS.has_feature("mobile") or "--mobile-test" in OS.get_cmdline_user_args()
var _mobile_detail_key := ""

func _ready() -> void:
	test_mode = "--smoke-test" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args() or "--gallery" in OS.get_cmdline_user_args() or "--integration" in OS.get_cmdline_user_args() or "--reel" in OS.get_cmdline_user_args()
	get_tree().auto_accept_quit = false
	_setup_input()
	_load_game()
	_load_settings()
	_setup_environment()
	for i in range(NAMES.size()):
		var world = World.new()
		add_child(world)
		world.position = CENTERS[i]
		world.setup(i, RADII[i])
		worlds.append(world)
		var dock = Art.rocket()
		world.add_child(dock)
		_surface(dock, _anchor(i, "rocket", Vector3(-0.35, 1, 0.15).normalized()), RADII[i] + 0.05)
	for i in range(NEIGHBOR_NAMES.size()):
		var planet: int = NEIGHBOR_PLANETS[i]
		var neighbor = Art.neighbor(i)
		worlds[planet].add_child(neighbor)
		_surface(neighbor, _anchor(planet, "neighbor", Vector3(0.25,1,0).normalized()), RADII[planet])
		neighbor.scale = Vector3.ONE*1.2
		worlds[planet].obstacles.append({"normal":neighbor.position.normalized(),"radius":0.36,"kind":"neighbor"})
		neighbors.append(neighbor)
		var controller = NeighborMotionController.new()
		controller.setup(neighbor,i)
		neighbor_motions.append(controller)
		var tag = Label3D.new()
		tag.text = NEIGHBOR_NAMES[i]
		tag.position.y = 1.6
		tag.font_size = 40
		tag.pixel_size = 0.007
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.modulate = Color("fff0d5")
		neighbor.add_child(tag)
	player = Node3D.new()
	add_child(player)
	avatar = Art.astronaut()
	player.add_child(avatar)
	avatar.scale = Vector3.ONE*1.4
	motion = Motion.new()
	motion.setup(avatar)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 41
	camera.far = 350
	hud = HUD.new()
	add_child(hud)
	hud.travel_requested.connect(_travel)
	hud.decorate_requested.connect(_start_placement)
	hud.action_requested.connect(_on_hud_action)
	audio = Sound.new()
	add_child(audio)
	audio.set_music_volume(music_volume)
	audio.set_effects_volume(effects_volume)
	AudioServer.set_bus_mute(0,muted)
	hud.dialogue_blip.connect(audio.play_voice)
	hud.dialogue_finished.connect(audio.stop_voice)
	touch_controls = Touch.new()
	add_child(touch_controls)
	touch_controls.action_requested.connect(_touch_action)
	touch_controls.camera_drag.connect(_touch_camera)
	if OS.has_feature("web"):
		hud.set_safe_area_insets(Vector4.ZERO)
	if hud.has_method("set_sound_enabled"):
		hud.set_sound_enabled(not muted)
	for entry in placed:
		_spawn_decoration(entry)
	_spawn_pickups()
	_apply_suit()
	_update_status()
	_update_player(0)
	_update_camera(1.0)
	if not test_mode:
		at_title = true
		player.visible = false
		hud.show_start_menu(save_available)
		_update_camera(5)
	_sync_touch()
	_update_mobile_details()
	screenshot_test = "--capture" in OS.get_cmdline_user_args()
	if "--reel" in OS.get_cmdline_user_args():
		call_deferred("_reel")
	if "--gallery" in OS.get_cmdline_user_args():
		call_deferred("_gallery")
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("_smoke_test")

func _setup_input() -> void:
	var keys = {"move_left":KEY_A, "move_right":KEY_D, "move_up":KEY_W, "move_down":KEY_S, "hop":KEY_SPACE, "interact":KEY_E, "map":KEY_M, "decorate":KEY_B, "rotate_item":KEY_R, "remove_item":KEY_X,"sound":KEY_V,"run":KEY_SHIFT,"journal":KEY_J,"camera":KEY_C,"help":KEY_H}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event = InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action,event)

	var pad_buttons = {"hop":JOY_BUTTON_A,"interact":JOY_BUTTON_X,"decorate":JOY_BUTTON_Y,"map":JOY_BUTTON_BACK,"journal":JOY_BUTTON_START,"run":JOY_BUTTON_RIGHT_SHOULDER,"camera":JOY_BUTTON_LEFT_SHOULDER,"remove_item":JOY_BUTTON_RIGHT_STICK}
	for action in pad_buttons:
		var button = InputEventJoypadButton.new()
		button.device = -1
		button.button_index = pad_buttons[action]
		if not InputMap.action_has_event(action,button):
			InputMap.action_add_event(action,button)
	var pad_axes = {"move_left":[JOY_AXIS_LEFT_X,-1.0],"move_right":[JOY_AXIS_LEFT_X,1.0],"move_up":[JOY_AXIS_LEFT_Y,-1.0],"move_down":[JOY_AXIS_LEFT_Y,1.0]}
	for action in pad_axes:
		InputMap.action_set_deadzone(action,0.2)
		var axis = InputEventJoypadMotion.new()
		axis.device = -1
		axis.axis = pad_axes[action][0]
		axis.axis_value = pad_axes[action][1]
		if not InputMap.action_has_event(action,axis):
			InputMap.action_add_event(action,axis)

	var ui_pad = {"ui_accept":JOY_BUTTON_A,"ui_cancel":JOY_BUTTON_B,"ui_left":JOY_BUTTON_DPAD_LEFT,"ui_right":JOY_BUTTON_DPAD_RIGHT,"ui_up":JOY_BUTTON_DPAD_UP,"ui_down":JOY_BUTTON_DPAD_DOWN}
	for action in ui_pad:
		var button = InputEventJoypadButton.new()
		button.device = -1
		button.button_index = ui_pad[action]
		if not InputMap.action_has_event(action,button):
			InputMap.action_add_event(action,button)
	for action in ["ui_left","ui_right","ui_up","ui_down"]:
		var axis = InputEventJoypadMotion.new()
		axis.device = -1
		axis.axis = JOY_AXIS_LEFT_X if action in ["ui_left","ui_right"] else JOY_AXIS_LEFT_Y
		axis.axis_value = -1.0 if action in ["ui_left","ui_up"] else 1.0
		if not InputMap.action_has_event(action,axis):
			InputMap.action_add_event(action,axis)

func _setup_environment() -> void:
	var env = WorldEnvironment.new()
	var e = Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Atmosphere.make_sky()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("aec8ed")
	e.ambient_light_energy = 0.17 if mobile_profile else 0.32
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = not mobile_profile
	e.ssao_radius = 0.8
	e.ssao_intensity = 1.4
	e.ssao_light_affect = 0.3
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color("17283b")
	e.fog_depth_begin = 38.0
	e.fog_depth_end = 170.0
	e.fog_depth_curve = 1.3
	e.fog_sky_affect = 0.0
	env.environment = e
	add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-32,-12)
	sun.light_color = Color("fff0d5")
	sun.light_energy = 0.30 if mobile_profile else 0.75
	sun.light_angular_distance = 0.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30 if mobile_profile else 65
	if mobile_profile:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(28,145,0)
	fill.light_color = Color("a8baff")
	fill.light_energy = 0.08 if mobile_profile else 0.22
	add_child(fill)
	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	atmosphere.configure(CENTERS,RADII)

func _anchor(index:int, key:String, fallback:Vector3) -> Vector3:
	return worlds[index].anchors.get(key, fallback).normalized()

func _surface(node:Node3D, n:Vector3, radius:float, angle:float=0.0) -> void:
	var right = Vector3.RIGHT - n * n.dot(Vector3.RIGHT)
	if right.length_squared() < 0.01:
		right = Vector3.FORWARD.cross(n)
	right = right.normalized()
	node.transform = Transform3D(Basis(right,n,right.cross(n)).rotated(n,angle),n*radius)

func _process(delta:float) -> void:
	elapsed += delta
	_sync_touch()
	_update_mobile_details()
	if at_title and not hud.is_panel_open():
		hud.show_start_menu(save_available)
	atmosphere.animate(elapsed,delta)
	if flight:
		_update_flight(delta)
	else:
		_update_player(delta)
		_update_camera(delta)
		_update_hint()
		_update_preview()
	_update_neighbors(delta)
	for p in pickups:
		if is_instance_valid(p.node):
			p.node.rotate_object_local(Vector3.UP,delta*0.6)
	save_timer += delta
	if save_timer > 20:
		save_timer = 0
		_save_game()
	if screenshot_test and elapsed > 4:
		screenshot_test = false
		_capture()

func _update_player(delta:float) -> void:
	var up = normal
	if not hud.is_panel_open() and not flight:
		for device in Input.get_connected_joypads():
			var stick = Vector2(Input.get_joy_axis(device,JOY_AXIS_RIGHT_X),Input.get_joy_axis(device,JOY_AXIS_RIGHT_Y))
			if stick.length() > 0.2:
				orbit -= stick.x*delta*1.6
				pitch = clampf(pitch+stick.y*delta*2.0,-3,5)
	var cam_right = camera.global_basis.x if camera else Vector3.RIGHT
	var right = _tangent(up,cam_right)
	var forward = right.cross(up).normalized()
	var input = Input.get_vector("move_left","move_right","move_up","move_down") if not hud.is_panel_open() and not at_title else Vector2.ZERO
	running = Input.is_action_pressed("run") and input.length_squared() > 0.01 and selected < 0 and not flight and not hud.is_panel_open()
	var desired = (right*input.x + forward*input.y) * (RUN_SPEED if running else WALK_SPEED)
	if hud.is_panel_open():
		velocity = Vector3.ZERO
	var acceleration = 16.0 if running else 12.0
	if input.is_zero_approx() or hud.is_panel_open():
		acceleration = 24.0
	velocity = velocity.move_toward(desired, delta*acceleration)
	velocity -= normal * velocity.dot(normal)
	run_amount = clampf((velocity.length()-WALK_SPEED)/(RUN_SPEED-WALK_SPEED),0,1)
	walking = velocity.length() > 0.15
	if walking:
		# Short surface steps keep a faster run from crossing narrow obstacles in a slow frame.
		var steps = maxi(1,ceili(velocity.length()*delta/0.16))
		for step in range(steps):
			var tangent_velocity = velocity-normal*velocity.dot(normal)
			normal = _resolve_surface((normal + tangent_velocity*delta/(steps*RADII[current])).normalized())
		facing = velocity.normalized()
		if elapsed-last_step > lerpf(0.34,0.23,run_amount) and hop <= 0:
			audio.play_cue("step")
			last_step = elapsed
	if hop > 0 or hop_speed > 0:
		hop_speed -= delta*9
		hop = maxf(0, hop+hop_speed*delta)
		if hop == 0:
			hop_speed = 0
	var tangent = _tangent(normal,facing)
	var basis = Basis(normal.cross(tangent).normalized(),normal,tangent)
	player.global_transform = Transform3D(basis,CENTERS[current]+normal*(RADII[current]+0.04+hop))
	motion.animate(elapsed,walking,hop>0,delta,run_amount)
	avatar.position.y = motion.bob
	avatar.rotation.x = motion.lean
	avatar.rotation.y = motion.twist
	avatar.rotation.z = motion.sway

func _on_hud_action(action: String) -> void:
	audio.resume_on_user_gesture()
	_action(action)
	_sync_touch()

func _sync_touch() -> void:
	if is_instance_valid(touch_controls):
		touch_controls.set_game_state(at_title or hud.is_panel_open(), selected >= 0, flight)
		hud.set_touch_controls_active(touch_controls.is_touch_enabled(), touch_controls.get_reserved_height())

func _using_touch() -> bool:
	return is_instance_valid(touch_controls) and touch_controls.is_touch_enabled()

func _touch_action(action: String) -> void:
	if at_title or flight or hud.is_panel_open():
		_sync_touch()
		return
	audio.resume_on_user_gesture()
	match action:
		"hop":
			if hop == 0:
				hop_speed = 4.3
				audio.play_cue("jump")
		"interact":
			_interact()
		"rotate_item":
			if selected >= 0:
				placement_angle += PI / 4.0
		"remove_item":
			_remove_nearest()
		"confirm_placement":
			_place_decoration()
		"pause":
			if selected >= 0:
				_cancel_placement()
			else:
				_show_pause()
		_:
			_action(action)
	_sync_touch()

func _touch_camera(relative: Vector2) -> void:
	if not at_title and not flight and not hud.is_panel_open():
		orbit -= relative.x * 0.006
		pitch = clampf(pitch + relative.y * 0.025, -3, 5)

func _show_pause() -> void:
	hud.show_choices("Take a little breather", "Your neighborhood will be here when you are ready.", [{"label":"Back to my world","action":"close"},{"label":"Settings","action":"settings"},{"label":"Save and return to start","action":"title"}])

func _update_mobile_details() -> void:
	if not mobile_profile:
		return
	var key := "%d:%d:%s:%s" % [current, flight_target, flight, at_title]
	if key == _mobile_detail_key:
		return
	_mobile_detail_key = key
	for index in range(worlds.size()):
		var active := index == current or (flight and index == flight_target) or (at_title and index == 0)
		worlds[index].set_landscape_detail(active)
		for child in worlds[index].get_children():
			if child is Node3D and child != worlds[index]._root:
				child.visible = active

func _update_camera(delta:float) -> void:
	# Parallel transport a tangent heading. A fixed global north reverses at
	# the poles, turning a continuous walk into a sudden camera flip.
	if camera_planet != current:
		camera_north = _tangent(normal,Vector3.BACK)
		camera_planet = current
	else:
		var transport = Quaternion(camera_up,normal)
		camera_north = _tangent(normal,transport*camera_north)
	camera_up = normal
	var north = camera_north.rotated(normal,orbit)
	var target = CENTERS[current] + normal * (RADII[current]*0.53)
	var framing_distance = distance + maxf(0,RADII[current]-8.0)*0.9
	var desired = CENTERS[current] + normal*(RADII[current]+framing_distance*0.88+pitch) + north*framing_distance*0.78
	if not overview:
		var cozy_distance = distance * 0.51
		target = CENTERS[current]+normal*(RADII[current]+0.75)-north*1.5
		desired = CENTERS[current]+normal*(RADII[current]+cozy_distance*0.80+pitch*0.45)+north*cozy_distance*0.9
	if at_title:
		var angle = elapsed*0.022
		var back = Vector3(sin(angle)*0.2,0.75,1.0).normalized()
		var title_right = Vector3.UP.cross(back).normalized()
		target = CENTERS[0]+Vector3.UP*2.5+title_right*5.0
		desired = CENTERS[0]+back*29.0+title_right*5.0
		camera.global_position = camera.global_position.lerp(desired,1.0-exp(-delta*3.0))
		camera.look_at(target,Vector3.UP)
		return
	if conversation and hud.is_panel_open():
		var talk_back = conversation_back
		var right = normal.cross(talk_back).normalized()
		target = conversation_focus + normal*0.72 + right*1.1
		desired = conversation_focus + normal*3.2 + talk_back*6.1 + right*1.1
		var viewport_size := get_viewport().get_visible_rect().size
		if viewport_size.x < 720 or viewport_size.y < 500 or _using_touch():
			# Compose faces in the free area above the actual bubble. A phone's
			# portrait width cannot carry the desktop's rightward framing offset.
			target -= right * 1.1
			desired -= right * 1.1
			var panel: Control = hud.get("_panel")
			var bubble_top := panel.get_global_rect().position.y if is_instance_valid(panel) else viewport_size.y * 0.48
			var face_center := conversation_focus + normal * 1.04
			var view_back: Vector3 = (desired - target).normalized()
			var view_up: Vector3 = (normal - view_back * normal.dot(view_back)).normalized()
			var depth := maxf(1.0, (face_center - desired).dot(-view_back))
			var focal := viewport_size.y / (2.0 * tan(deg_to_rad(camera.fov) * 0.5))
			var projected_y: float = viewport_size.y * 0.5 - (face_center - desired).dot(view_up) * focal / depth
			var intended_y := lerpf(minf(64.0, bubble_top * 0.3), bubble_top, 0.53)
			var offset := clampf((projected_y - intended_y) * depth / focal, -1.5, 2.2)
			target -= view_up * offset
			desired -= view_up * offset
	else:
		conversation = false
		for neighbor in neighbors:
			for label in neighbor.find_children("*","Label3D",true,false):
				label.visible = true
	camera.global_position = camera.global_position.lerp(desired,1.0-exp(-delta*5.0))
	camera.look_at(target,normal)

func _input(event:InputEvent) -> void:
	# A plays in the world and accepts inside menus. An old footer focus must
	# never steal a jump after a controller closes a panel.
	if is_instance_valid(hud) and not hud.is_panel_open() and not at_title and not flight:
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			_unhandled_input(event)
			get_viewport().set_input_as_handled()

func _unhandled_input(event:InputEvent) -> void:
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed):
		if event.is_action_pressed("ui_cancel"):
			if selected >= 0:
				_cancel_placement()
			elif hud.is_panel_open():
				hud.close_panel()
			elif not flight:
				_show_pause()
		if at_title:
			if event.is_action_pressed("ui_cancel"):
				hud.show_start_menu(save_available)
			return
		if flight:
			return
		if event.is_action_pressed("sound"):
			_action("sound")
		elif event.is_action_pressed("journal"):
			_action("journal")
		elif event.is_action_pressed("camera"):
			_action("camera")
		elif event.is_action_pressed("help"):
			_action("help")
		elif event.is_action_pressed("map"):
			_action("map")
		elif event.is_action_pressed("decorate"):
			if selected >= 0 and event is InputEventJoypadButton:
				placement_angle += PI/4
			else:
				_action("decorate")
		elif event.is_action_pressed("interact") and not hud.is_panel_open():
			_interact()
		elif event.is_action_pressed("hop") and not hud.is_panel_open():
			if selected >= 0 and event is InputEventJoypadButton:
				_place_decoration()
			elif hop == 0:
				hop_speed = 4.3
				audio.play_cue("jump")
		elif event.is_action_pressed("rotate_item"):
			placement_angle += PI/4
		elif event.is_action_pressed("remove_item") and not hud.is_panel_open():
			_remove_nearest()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not flight and not at_title and not hud.is_panel_open():
		orbit -= event.relative.x*0.006
		pitch = clampf(pitch+event.relative.y*0.025,-3,5)
	if event is InputEventMouseButton and event.pressed and not flight and not hud.is_panel_open():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance-1,13,27)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance+1,13,27)
		if event.button_index == MOUSE_BUTTON_LEFT and selected >= 0 and not hud.is_panel_open():
			_place_decoration()

func _update_status() -> void:
	hud.set_status(NAMES[current], SUBTITLES[current], stars)

func _near(n:Vector3, threshold:float=2.4) -> bool:
	return normal.distance_to(n)*RADII[current] < threshold

func _update_hint() -> void:
	var use_hint := "Use  ·  " if _using_touch() else "E  ·  "
	if selected >= 0:
		var issue = _placement_issue(_placement_normal())
		hud.set_hint(("Ready to place " + ITEMS[selected] if issue.is_empty() else "Cannot place: " + issue) + ("  ·  Tap Place or Rotate" if _using_touch() else "  ·  Click place  ·  R rotate  ·  Esc cancel"))
		return
	for p in pickups:
		if p.planet == current and is_instance_valid(p.node) and not p.node.is_queued_for_deletion() and _near(p.normal,1.9):
			hud.set_hint(use_hint + "Gather " + p.title)
			return
	if current in NEIGHBOR_PLANETS:
		if _near(_anchor(current,"neighbor",Vector3(0.25,1,0).normalized())):
			hud.set_hint(use_hint + "Talk to " + NEIGHBOR_NAMES[NEIGHBOR_PLANETS.find(current)])
			return
	if current == 3:
		for key in ["town_hall","shop","clothes","event"]:
			if _near(_anchor(3,key,Vector3.UP),2.8):
				hud.set_hint(use_hint + {"town_hall":"Visit town hall","shop":"Browse Orbit Objects","clothes":"Try a new spacesuit","event":"Make a wish"}[key])
				return
	if _near(_anchor(current,"rocket",Vector3(-0.35,1,0.15).normalized()),3):
		hud.set_hint(use_hint + "Board the Little Dipper")
	else:
		hud.set_hint("Wander a while. There is no hurry.")

func _interact() -> void:
	for p in pickups:
		if p.planet == current and is_instance_valid(p.node) and not p.node.is_queued_for_deletion() and _near(p.normal,1.9):
			collected_bits[p.quest] = int(collected_bits[p.quest]) | (1 << int(p.get("slot",0)))
			quest_progress[p.quest] += 1
			var request = Neighbourhood.quest(p.quest,quest_round[p.quest])
			cargo[p.quest] = quest_progress[p.quest] >= int(request.target)
			p.node.queue_free()
			audio.play_cue("collect")
			hud.toast("Found " + p.title + ("! Bring it to " + NEIGHBOR_NAMES[p.quest] + "." if cargo[p.quest] else " · " + str(quest_progress[p.quest]) + "/" + str(request.target) + " gathered"))
			_save_game()
			return
	if current in NEIGHBOR_PLANETS and _near(_anchor(current,"neighbor",Vector3(0.25,1,0).normalized())):
		_talk(NEIGHBOR_PLANETS.find(current))
		return
	if current == 3:
		for key in ["town_hall","shop","clothes","event"]:
			if _near(_anchor(3,key,Vector3.UP),2.8):
				_town(key)
				return
	if _near(_anchor(current,"rocket",Vector3(-0.35,1,0.15).normalized()),3):
		_action("map")

func _talk(who:int) -> void:
	if who < 0 or who >= neighbors.size():
		return
	velocity = Vector3.ZERO
	running = false
	conversation = true
	neighbor_motions[who].greet()
	conversation_focus = (neighbors[who].global_position+player.global_position)*0.5
	facing = _tangent(normal,neighbors[who].global_position-player.global_position)
	_update_player(0)
	conversation_back = _choose_conversation_view(neighbors[who].global_position)
	for label in neighbors[who].find_children("*","Label3D",true,false):
		label.visible = false
	audio.play_cue("dialog")
	var name_text = NEIGHBOR_NAMES[who]
	var request = Neighbourhood.quest(who,quest_round[who])
	talk_counts[who] += 1
	_refresh_favor_progress()
	if favors[who] == 0:
		favors[who] = 1
		quest_round[who] = friendship[who]
		request = Neighbourhood.quest(who,quest_round[who])
		_refresh_favor_progress()
		_spawn_pickups()
		hud.show_dialog(name_text,request.request,"I'll find it!" if request.type in ["retrieve","collect"] else "I'd love to!")
	elif favors[who] == 1 and cargo[who]:
		favors[who] = 2
		friendship[who] += 1
		cargo[who] = false
		var reward = randi_range(0,ITEMS.size()-1)
		inventory[reward] += 1
		stars += 25
		var milestone = Neighbourhood.milestone(friendship[who])
		hud.show_dialog(name_text,request.thank_you + "\n\nI made you a " + ITEMS[reward] + ". And here are 25 stardust for your next adventure." + ("\n\n"+milestone if not milestone.is_empty() else ""),"Thank you!")
		audio.play_cue("collect")
	elif favors[who] == 1:
		hud.show_dialog(name_text,Neighbourhood.chatter(who,friendship[who],talk_counts[who])+"\n\n"+request.reminder+"\n\n"+_favor_progress_text(who),"See you soon")
	else:
		hud.show_dialog(name_text,Neighbourhood.chatter(who,friendship[who],talk_counts[who]),"Another little favor?", "favor"+str(who))
	_update_status()
	_save_game()

func _refresh_favor_progress() -> void:
	for who in range(NEIGHBOR_NAMES.size()):
		if favors[who] != 1:
			continue
		var request = Neighbourhood.quest(who,quest_round[who])
		if request.type == "decorate":
			quest_progress[who] = mini(placed.size(),int(request.target))
			cargo[who] = quest_progress[who] >= int(request.target)

func _favor_progress_text(who:int) -> String:
	var request = Neighbourhood.quest(who,quest_round[who])
	if cargo[who]:
		return "All ready! Visit " + NEIGHBOR_NAMES[who] + " on " + NAMES[NEIGHBOR_PLANETS[who]] + "."
	return str(quest_progress[who])+" / "+str(request.target)+" · "+request.title

func _journal_entries() -> Array:
	_refresh_favor_progress()
	var entries:Array = []
	for who in range(NEIGHBOR_NAMES.size()):
		var request = Neighbourhood.quest(who,quest_round[who])
		var body = "Visit " + NEIGHBOR_NAMES[who] + " on " + NAMES[NEIGHBOR_PLANETS[who]] + " to share a hello."
		var progress = "A new face in the neighborhood"
		if favors[who] == 1:
			body = request.reminder
			progress = _favor_progress_text(who)
		elif favors[who] == 2:
			body = "A lovely favor, finished. Stop by for a chat and another small adventure."
			progress = str(friendship[who])+(" favor shared" if friendship[who] == 1 else " favors shared")
		entries.append({"who":who,"name":NEIGHBOR_NAMES[who],"location":NAMES[NEIGHBOR_PLANETS[who]],"friendship":Neighbourhood.friendship_name(friendship[who]),"title":NEIGHBOR_NAMES[who]+" · "+Neighbourhood.friendship_name(friendship[who]),"body":body,"progress":progress})
	entries.append({"title":"Your little corner of the cosmos","body":"Shop for handmade objects at the Commons, or help a neighbor for a surprise. Every object can be picked up and placed again.","progress":"%d %s at home · %d %s sent" % [placed.size(),"decoration" if placed.size() == 1 else "decorations",wishes,"wish" if wishes == 1 else "wishes"]})
	return entries

func _town(key:String) -> void:
	match key:
		"town_hall":
			hud.show_journal(_journal_entries())
		"shop":
			hud.show_shop(Catalog.entries(inventory),stars)
		"clothes":
			hud.show_wardrobe(suit,Catalog.SUIT_NAMES,Catalog.SUIT_COLORS)
		"event":
			hud.show_dialog("The wishing lawn","Close your eyes. Think of one small good thing. Somewhere in this enormous universe, someone is wishing for exactly the same thing.","Send a little wish","wish")

func _action(action:String) -> void:
	if flight:
		return
	if action in ["continue", "new_game", "confirm_new_game"]:
		audio.resume_on_user_gesture()
	if action.begins_with("music:"):
		music_volume = clampf(float(action.trim_prefix("music:")),0,1)
		audio.set_music_volume(music_volume)
		_save_settings()
		return
	if action.begins_with("effects:"):
		effects_volume = clampf(float(action.trim_prefix("effects:")),0,1)
		audio.set_effects_volume(effects_volume)
		audio.play_cue("dialog")
		_save_settings()
		return
	match action:
		"continue":
			at_title = false
			player.visible = true
			hud.close_panel()
			hud.toast("Welcome home, little explorer.")
			return
		"title":
			if not _save_game():
				return
			at_title = true
			player.visible = false
			hud.show_start_menu(save_available)
			return
		"new_game":
			if FileAccess.file_exists(SAVE_PATH):
				hud.show_choices("A fresh little beginning?","This starts a new neighborhood. Your current home and friendships will be replaced. A copy of the previous save will be kept as orbit_save.backup.json.",[{"label":"Keep my current orbit","action":"back_to_title"},{"label":"Start a new orbit","action":"confirm_new_game"}])
			else:
				_begin_new_game()
			return
		"confirm_new_game":
			_begin_new_game()
			return
		"settings":
			hud.show_settings(music_volume,effects_volume,DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,not muted)
			return
		"fullscreen":
			var active = DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if active else DisplayServer.WINDOW_MODE_FULLSCREEN)
			hud.show_settings(music_volume,effects_volume,not active,not muted)
			_save_settings()
			return
		"back_to_title":
			if at_title:
				hud.show_start_menu(save_available)
			else:
				hud.close_panel()
			return
		"quit_without_save":
			_finish_quit()
			return
		"quit":
			_quit_game()
			return
	if at_title and action not in ["help","sound"]:
		return
	if action.begins_with("buy_item:"):
		var kind = int(action.trim_prefix("buy_item:"))
		if kind >= 0 and kind < ITEMS.size():
			if stars < Catalog.PRICES[kind]:
				hud.toast("A little more stardust needed. Help a neighbor to earn more.")
			else:
				stars -= Catalog.PRICES[kind]
				inventory[kind] += 1
				audio.play_cue("collect")
				if hud.has_method("refresh_shop"):
					hud.refresh_shop(stars,ITEMS[kind])
				hud.toast("Wrapped with care: " + ITEMS[kind] + ".")
				_update_status()
				_save_game()
		return
	if action.begins_with("wear:"):
		var choice = int(action.trim_prefix("wear:"))
		if choice >= 0 and choice < Catalog.SUIT_NAMES.size():
			suit = choice
			_apply_suit()
			hud.toast("Ready for a new orbit in " + Catalog.SUIT_NAMES[suit] + ".")
			_save_game()
		return
	if action.begins_with("favor"):
		var who = int(action.trim_prefix("favor"))
		if who >= 0 and who < NEIGHBOR_NAMES.size() and favors[who] == 2:
			favors[who] = 0
			cargo[who] = false
			quest_progress[who] = 0
			collected_bits[who] = 0
			quest_round[who] = friendship[who]
			_spawn_pickups()
			_talk(who)
		return
	match action:
		"journal":
			_cancel_placement()
			hud.show_journal(_journal_entries())
		"help":
			hud.show_dialog("A little field guide", _field_guide_text(), "Back to my little world")
		"camera":
			overview = not overview
			hud.toast("A view of your little planet." if overview else "A little closer to home.")
			_save_game()
		"sound":
			muted = not muted
			AudioServer.set_bus_mute(0,muted)
			if hud.has_method("set_sound_enabled"):
				hud.set_sound_enabled(not muted)
			if hud.is_panel_open() and hud.get("_settings_open") == true:
				hud.show_settings(music_volume,effects_volume,DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,not muted)
			hud.toast("Sound off. A quiet little universe." if muted else "Sound on. Listen to the stars.")
			_save_settings()
		"map":
			_cancel_placement()
			hud.show_travel(current)
		"decorate":
			if current != 0:
				hud.toast("Your decorations belong on Clover. Let's take them home.")
				return
			hud.show_inventory(Catalog.entries(inventory))
		"buy":
			if stars < 15:
				hud.toast("A parcel costs 15 stardust. Help a neighbor to earn more.")
			else:
				stars -= 15
				var kind = randi_range(0,ITEMS.size()-1)
				inventory[kind] += 1
				hud.toast("Unwrapped: " + ITEMS[kind] + ". Find it in your decorating bag.")
				audio.play_cue("collect")
			_update_status()
			_save_game()
		"suit":
			suit = (suit+1)%Catalog.SUIT_NAMES.size()
			_apply_suit()
			hud.toast("A lovely new look for your next small adventure.")
			_save_game()
		"wish":
			wishes += 1
			atmosphere.wish(player.global_position+normal*1.3,normal)
			_record_favor_event("wish",current)
			_save_game()
			audio.play_cue("collect")
			hud.toast("Your wish is on its way. ✦")

func _begin_new_game() -> void:
	if not test_mode and FileAccess.file_exists(SAVE_PATH):
		var backup_error = DirAccess.copy_absolute(SAVE_PATH,"user://orbit_save.backup.json")
		if backup_error != OK:
			hud.show_dialog("Your current orbit is safe","The previous save could not be backed up. Let's keep your neighborhood as it is for now.","Back","back_to_title")
			return
	stars = 30
	inventory = [2,1,1,1,1,2,0,0,0,0,0,0,0,0,0,0,0,0]
	favors = [0,0,0,0]
	friendship = [0,0,0,0]
	cargo = [false,false,false,false]
	quest_round = [0,0,0,0]
	quest_progress = [0,0,0,0]
	collected_bits = [0,0,0,0]
	talk_counts = [0,0,0,0]
	wishes = 0
	suit = 0
	current = 0
	normal = Vector3(0,1,0.35).normalized()
	facing = Vector3.BACK
	velocity = Vector3.ZERO
	hop = 0
	hop_speed = 0
	orbit = 0
	pitch = 0
	distance = 19
	overview = false
	conversation = false
	camera_planet = -1
	_cancel_placement()
	for node in placed_nodes:
		if is_instance_valid(node):
			node.queue_free()
	placed_nodes.clear()
	placed.clear()
	for pickup in pickups:
		if is_instance_valid(pickup.node):
			pickup.node.queue_free()
	pickups.clear()
	_spawn_pickups()
	_apply_suit()
	at_title = false
	player.visible = true
	_update_player(0)
	_update_status()
	var arrival_controls := "Use the left joystick to wander. Tap Run for a little sprint and Use beside someone curious. Map takes you to your neighbors; Bag holds your decorations." if _using_touch() else "Walk with WASD, hold Shift for a little run, and press E beside someone curious. M opens the map; B opens your decorating bag."
	hud.show_dialog("A small home. A big universe.", "Welcome to Clover. This little planet is yours to make lovely.\n\nLumi, Bolt, Pip and Miso are waiting to meet you. Help with their little favors for handmade gifts and stardust. Your journal keeps track.\n\n" + arrival_controls, "Make yourself at home")
	_save_game()

func _apply_suit() -> void:
	var colors = Catalog.SUIT_COLORS
	var light = player.get_node_or_null("SuitGlow")
	if light == null:
		light = OmniLight3D.new()
		light.name = "SuitGlow"
		player.add_child(light)
		light.position.y = 0.7
		light.omni_range = 2
		light.light_energy = 0.0 if mobile_profile else 0.45
	light.light_color = colors[suit]
	for child in avatar.find_children("*","MeshInstance3D",true,false):
		if child.get_meta("suit_accent",false):
			var mat = StandardMaterial3D.new()
			mat.albedo_color = colors[suit]
			mat.roughness = 0.7
			child.material_override = mat

func _field_guide_text() -> String:
	var controls := "WASD · Walk    Shift · Run    Space · Hop\nE · Talk, gather and visit\nM · Map    B · Bag    J · Journal\nC · Camera    V · Sound    Esc · Pause\nRight-drag · Look around    Scroll · Zoom\n\nController: left stick to move, RB to run, A to hop, X to interact, Y for your bag. Back opens the map, Start the journal and LB changes the camera. A selects and B returns in menus.\n\nDecorating: click or controller A to place, R or Y to rotate, X or right-stick click to pick up. Esc or B puts your tools away."
	if _using_touch():
		controls = "Move with the left joystick. Tap Run to switch between walking and running, and Jump for a little hop. Drag the open sky to look around.\n\nTap Use beside a neighbor, collectible or shop. Map takes you to another world. Bag opens your decorations on Clover. Pause gives you settings and a way back to the start.\n\nWhile decorating, tap Rotate to turn an object, Place to set it down, and Refund beside an object to return it to your bag. Pause puts your tools away.\n\nTap a dialogue to reveal the rest. Tap its reply to finish your chat."
	return controls + "\n\nHelp Lumi, Bolt, Pip and Miso for stardust and handmade gifts. Browse objects and complimentary spacesuits at the Commons. Your neighborhood saves automatically." + (" Browser saves belong to this device and browser." if OS.has_feature("web") else "")

func _record_favor_event(event_type:String,planet:int) -> void:
	for who in range(NEIGHBOR_NAMES.size()):
		var request = Neighbourhood.quest(who,quest_round[who])
		if favors[who] == 1 and request.type == event_type and int(request.planet) == planet:
			quest_progress[who] = int(request.target)
			cargo[who] = true
			hud.toast("A little favor, ready to share. Visit " + NEIGHBOR_NAMES[who] + ".")

func _spawn_pickups() -> void:
	var keep:Array = []
	for pickup in pickups:
		if not is_instance_valid(pickup.node) or pickup.node.is_queued_for_deletion():
			continue
		if int(pickup.get("round",0)) != int(quest_round[pickup.quest]) or favors[pickup.quest] == 2:
			pickup.node.queue_free()
		else:
			keep.append(pickup)
	pickups = keep
	for q in range(NEIGHBOR_NAMES.size()):
		if favors[q] == 2 or cargo[q]:
			continue
		var request = Neighbourhood.quest(q,quest_round[q])
		if not request.type in ["retrieve","collect"]:
			continue
		for slot in range(int(request.target)):
			if int(collected_bits[q]) & (1 << slot):
				continue
			var exists := false
			for pickup in pickups:
				if pickup.quest == q and int(pickup.get("slot",0)) == slot:
					exists = true
			if exists:
				continue
			var planet = int(request.planet)
			var n = Vector3(0.38,1,0.40).normalized() if q == 0 else Vector3(-0.12,1,0.46).normalized()
			if quest_round[q] > 0 or request.type == "collect":
				n = [Vector3(-0.52,1,0.6),Vector3(0.65,1,0.6),Vector3(0.03,1,0.95),Vector3(-0.36,1,1.45)][slot%4].normalized()
			var node = _quest_token(q,request.token)
			worlds[planet].add_child(node)
			_surface(node,n,RADII[planet]+0.15)
			pickups.append({"planet":planet,"normal":n,"node":node,"quest":q,"slot":slot,"round":quest_round[q],"title":{"star":"a fallen star","coil":"a copper coil","seed":"a moonbean seed","gear":"a brass gear","crystal":"a crystal"}.get(request.token,"a little treasure")})

func _start_placement(kind:int) -> void:
	if current != 0 or kind < 0 or kind >= ITEMS.size() or inventory[kind] <= 0:
		return
	_cancel_placement()
	selected = kind
	preview = Art.decoration(kind)
	worlds[0].add_child(preview)
	preview_material = StandardMaterial3D.new()
	preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mesh in preview.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = preview_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring = MeshInstance3D.new()
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = _decoration_radius(kind)-0.025
	ring_mesh.outer_radius = _decoration_radius(kind)+0.025
	ring_mesh.rings = 48
	ring_mesh.ring_segments = 8
	ring.mesh = ring_mesh
	ring.material_override = preview_material
	ring.position.y = 0.07
	preview.add_child(ring)
	hud.toast("Find a lovely spot. Click to place, R to rotate.")

func _placement_normal() -> Vector3:
	return (normal + facing*1.25/RADII[0]).normalized()

func _update_preview() -> void:
	if is_instance_valid(preview):
		_surface(preview,_placement_normal(),RADII[0]+0.04,placement_angle)
		preview_material.albedo_color = Color(0.55,1.0,0.78,0.58) if _placement_issue(_placement_normal()).is_empty() else Color(1.0,0.38,0.32,0.6)

func _place_decoration() -> void:
	var n = _placement_normal()
	var issue = _placement_issue(n)
	if not issue.is_empty():
		hud.toast(issue)
		return
	var entry = {"kind":selected,"n":[n.x,n.y,n.z],"angle":placement_angle}
	placed.append(entry)
	_refresh_favor_progress()
	_spawn_decoration(entry)
	inventory[selected] -= 1
	audio.play_cue("place")
	hud.toast(ITEMS[selected] + " has found a home.")
	_cancel_placement()
	_save_game()

func _spawn_decoration(entry:Dictionary) -> void:
	var node = Art.decoration(int(entry.kind))
	worlds[0].add_child(node)
	_surface(node,Vector3(entry.n[0],entry.n[1],entry.n[2]).normalized(),RADII[0]+0.02,float(entry.angle))
	placed_nodes.append(node)

func _remove_nearest() -> void:
	if current != 0:
		return
	var closest := -1
	var dist := 2.4
	for i in range(placed.size()):
		var p = placed[i]
		var d = normal.distance_to(Vector3(p.n[0],p.n[1],p.n[2]))*RADII[0]
		if d < dist:
			dist = d
			closest = i
	if closest >= 0:
		inventory[int(placed[closest].kind)] += 1
		placed_nodes[closest].queue_free()
		placed_nodes.remove_at(closest)
		placed.remove_at(closest)
		_refresh_favor_progress()
		hud.toast("Tucked safely back into your decorating bag.")
		_save_game()

func _cancel_placement() -> void:
	if is_instance_valid(preview):
		preview.queue_free()
	preview = null
	selected = -1

func _travel(index:int) -> void:
	if index == current or index < 0 or index >= NAMES.size() or flight:
		return
	_cancel_placement()
	hud.close_panel()
	flight = true
	running = false
	run_amount = 0.0
	conversation = false
	if hud.has_method("set_travel_active"):
		hud.set_travel_active(true)
	flight_time = 0
	flight_origin = current
	flight_target = index
	flight_from = player.global_position + normal*1.4
	flight_to = CENTERS[index] + Vector3(0,1,0.35).normalized()*(RADII[index]+1.4)
	ship = Art.rocket()
	add_child(ship)
	ship.global_position = flight_from
	_make_exhaust(ship)
	player.visible = false
	audio.play_cue("travel")
	hud.set_hint("Next stop: " + NAMES[index] + "  ·  Enjoy the little things along the way")

func _update_flight(delta:float) -> void:
	flight_time += delta
	var t = clampf(flight_time/5.0,0,1)
	var smooth = t*t*(3-2*t)
	var arc = Vector3.UP*sin(t*PI)*14
	ship.global_position = flight_from.lerp(flight_to,smooth)+arc
	var direction = (flight_to-flight_from)*(6*t*(1-t)) + Vector3.UP*cos(t*PI)*14*PI
	if direction.length_squared() > 0.01:
		var up = direction.normalized().slerp(Vector3.UP,smoothstep(0.8,1.0,t)).normalized()
		ship.quaternion = Quaternion(Vector3.UP,up)
	var view = ship.global_position+Vector3(12,10,22)
	camera.global_position = camera.global_position.lerp(view,1-exp(-delta*3))
	camera.look_at(ship.global_position,Vector3.UP)
	if t >= 1:
		ship.queue_free()
		flight = false
		if hud.has_method("set_travel_active"):
			hud.set_travel_active(false)
		current = flight_target
		_record_favor_event("visit",current)
		normal = Vector3(0,1,0.35).normalized()
		velocity = Vector3.ZERO
		orbit = 0
		player.visible = true
		_update_status()
		hud.toast("Welcome to " + NAMES[current] + ".")
		_save_game()

func _save_game(destination:String=SAVE_PATH, allow_test:bool=false) -> bool:
	if (test_mode and not allow_test) or (at_title and not allow_test):
		return true
	var data = {"version":1,"stars":stars,"inventory":inventory,"favors":favors,"friendship":friendship,"cargo":cargo,"placed":placed,"suit":suit,"muted":muted,"planet":current,"normal":[normal.x,normal.y,normal.z],"quest_round":quest_round,"quest_progress":quest_progress,"collected_bits":collected_bits,"talk_counts":talk_counts,"wishes":wishes,"overview":overview,"music_volume":music_volume,"effects_volume":effects_volume}
	var file = FileAccess.open(destination+".tmp",FileAccess.WRITE)
	var error = FileAccess.get_open_error()
	if file:
		file.store_string(JSON.stringify(data))
		error = file.get_error()
		file.close()
		if error == OK:
			error = DirAccess.rename_absolute(destination+".tmp",destination)
	if error == OK:
		if destination == SAVE_PATH:
			save_available = true
			save_error_shown = false
		return true
	if not test_mode and not save_error_shown and is_instance_valid(hud):
		save_error_shown = true
		hud.toast("Your orbit could not be saved. Check available disk space and try again.")
	return false

func _load_game(source:String=SAVE_PATH, allow_test:bool=false) -> void:
	if test_mode and not allow_test:
		return
	if not FileAccess.file_exists(source):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(source))
	if not data is Dictionary or data.get("version") != 1:
		return
	save_available = true
	stars = maxi(0,int(data.get("stars",30)))
	if data.get("inventory") is Array and data.inventory.size() in [6,ITEMS.size()]:
		inventory.clear()
		for i in range(ITEMS.size()):
			inventory.append(clampi(int(data.inventory[i]),0,9999) if i < data.inventory.size() else 0)
	for key in ["favors","friendship","cargo","quest_round","quest_progress","collected_bits","talk_counts"]:
		if data.get(key) is Array and data[key].size() in [2, NEIGHBOR_NAMES.size()]:
			var values:Array = []
			for index in range(NEIGHBOR_NAMES.size()):
				var value = data[key][index] if index < data[key].size() else 0
				values.append(bool(value) if key == "cargo" else clampi(int(value),0,2 if key == "favors" else 9999))
			set(key,values)
	# Old saves contain one retrieval favor and six object slots. Keep every owned object.
	if not data.has("quest_progress"):
		for who in range(NEIGHBOR_NAMES.size()):
			quest_progress[who] = 1 if cargo[who] else 0
			collected_bits[who] = 1 if cargo[who] else 0
	wishes = maxi(0,int(data.get("wishes",0)))
	overview = bool(data.get("overview",false))
	music_volume = clampf(float(data.get("music_volume",0.18)),0,1)
	effects_volume = clampf(float(data.get("effects_volume",0.24)),0,1)
	placed.clear()
	var saved_placed = data.get("placed",[])
	if not saved_placed is Array:
		saved_placed = []
	for entry in saved_placed:
		if entry is Dictionary and int(entry.get("kind",-1)) in range(ITEMS.size()) and entry.get("n") is Array and entry.n.size() == 3 and entry.has("angle"):
			var n = Vector3(float(entry.n[0]),float(entry.n[1]),float(entry.n[2]))
			var angle = float(entry.angle)
			if n.is_finite() and n.length_squared() > 0.01 and is_finite(angle):
				n = n.normalized()
				placed.append({"kind":int(entry.kind),"n":[n.x,n.y,n.z],"angle":angle})
	suit = clampi(int(data.get("suit",0)),0,Catalog.SUIT_NAMES.size()-1)
	muted = bool(data.get("muted",false))
	current = clampi(int(data.get("planet",0)),0,NAMES.size()-1)
	var saved_normal = data.get("normal",[])
	if saved_normal is Array and saved_normal.size() == 3:
		var candidate = Vector3(float(saved_normal[0]),float(saved_normal[1]),float(saved_normal[2]))
		if candidate.is_finite() and candidate.length_squared() > 0.01:
			normal = candidate.normalized()

func _save_settings() -> void:
	if test_mode:
		return
	var file = FileAccess.open("user://orbit_settings.json.tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"music":music_volume,"effects":effects_volume,"muted":muted,"fullscreen":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN}))
		file.close()
		DirAccess.rename_absolute("user://orbit_settings.json.tmp","user://orbit_settings.json")

func _load_settings() -> void:
	if test_mode or not FileAccess.file_exists("user://orbit_settings.json"):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://orbit_settings.json"))
	if data is Dictionary:
		music_volume = clampf(float(data.get("music",music_volume)),0,1)
		effects_volume = clampf(float(data.get("effects",effects_volume)),0,1)
		muted = bool(data.get("muted",muted))
		if bool(data.get("fullscreen",false)):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _notification(what:int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not closing:
		_quit_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and not closing:
		# Mobile browsers may suspend immediately after a tab/app switch.
		_save_game()
		if is_instance_valid(audio):
			audio.stop_voice()

func _quit_game() -> void:
	if not _save_game():
		hud.show_choices("Your orbit has not saved","The latest progress could not be written. You can stay in the game and try again, or leave without these changes.",[{"label":"Stay in my orbit","action":"close"},{"label":"Quit without saving","action":"quit_without_save"}])
		return
	_finish_quit()

func _finish_quit() -> void:
	if closing:
		return
	if OS.has_feature("web"):
		# Browser tabs cannot be closed by the game; return to a usable title screen.
		at_title = true
		player.visible = false
		audio.stop_voice()
		hud.show_start_menu(save_available)
		_sync_touch()
		return
	closing = true
	if is_instance_valid(audio):
		audio.stop_all()
	# Allow the mixer to finish releasing stopped voices before engine shutdown.
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func _capture() -> void:
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("res://captures/clover.png")
	print("CAPTURE_COMPLETE")

func _smoke_test() -> void:
	await get_tree().process_frame
	assert(worlds.size() == 4)
	assert(neighbors.size() == 2)
	assert(player.global_position.is_finite())
	var before = stars
	_action("buy")
	assert(stars == before-15)
	_talk(0)
	assert(favors[0] >= 1)
	cargo[0] = true
	favors[0] = 1
	_talk(0)
	assert(favors[0] == 2)
	assert(stars == before+10)
	hud.close_panel()
	_travel(1)
	_update_flight(5.1)
	assert(current == 1 and not flight)
	print("SMOKE_TEST_PASS: worlds, neighbors, shop, favor reward, rocket travel")
	get_tree().quit()

func _resolve_surface(candidate:Vector3) -> Vector3:
	var blockers:Array = worlds[current].get("obstacles") if worlds[current].get("obstacles") != null else []
	for obstacle in blockers:
		var center:Vector3 = obstacle.normal
		var clearance:float = float(obstacle.radius) + 0.22
		if candidate.distance_to(center)*RADII[current] < clearance:
			var away = candidate - center*center.dot(candidate)
			if away.length_squared() < 0.00001:
				away = normal-center*center.dot(normal)
			candidate = (center + _tangent(center,away)*clearance/RADII[current]).normalized()
	if current == 0:
		for entry in placed:
			var center = Vector3(entry.n[0],entry.n[1],entry.n[2])
			var clearance = _decoration_radius(int(entry.kind))+0.22
			if candidate.distance_to(center)*RADII[0] < clearance:
				var away = candidate-center*center.dot(candidate)
				candidate = (center+_tangent(center,away)*clearance/RADII[0]).normalized()
	return candidate

func _gallery() -> void:
	await get_tree().create_timer(1.0).timeout
	set_process(false)
	hud.toast("")
	for i in range(4):
		current = i
		normal = Vector3(0,1,0.35).normalized()
		orbit = 0.0
		_update_player(0)
		_update_camera(5)
		_update_status()
		_update_hint()
		await _capture_frame(["clover","luma","rust","commons"][i])
	current = 1
	normal = (_anchor(1,"neighbor",Vector3.UP)+Vector3(0,0,0.20)).normalized()
	_update_player(0)
	_update_camera(5)
	_update_status()
	_talk(0)
	_update_camera(5)
	await _capture_frame("neighbor")
	hud.close_panel()
	conversation = false
	current = 3
	_update_player(0)
	_update_camera(5)
	_update_status()
	_town("shop")
	await _capture_frame("shop")
	hud.close_panel()
	current = 0
	_update_player(0)
	_update_camera(5)
	_update_status()
	_action("map")
	await _capture_frame("map")
	hud.close_panel()
	_action("decorate")
	await _capture_frame("inventory")
	hud.close_panel()
	var staged := false
	for z in [0.60,0.85,1.10]:
		for x in [-0.25,0.0,0.25,-0.5,0.5]:
			if staged:
				break
			normal = Vector3(x,1,z).normalized()
			facing = _tangent(normal,Vector3.BACK)
			_update_player(0)
			_start_placement(0)
			if not _placement_issue(_placement_normal()).is_empty():
				_cancel_placement()
				continue
			_update_camera(5)
			_update_preview()
			_update_hint()
			await _capture_frame("placement")
			var before = placed.size()
			var items_before = inventory[0]
			_place_decoration()
			assert(placed.size() == before+1 and inventory[0] == items_before-1)
			_update_hint()
			await _capture_frame("decorated")
			staged = true
	assert(staged, "Gallery needs a valid decorated location")
	normal = Vector3(0,1,0.35).normalized()
	facing = _tangent(normal,Vector3.FORWARD)
	_update_player(0)
	_update_camera(5)
	_start_placement(0)
	_update_preview()
	_update_hint()
	assert(not _placement_issue(_placement_normal()).is_empty())
	await _capture_frame("invalid_placement")
	_cancel_placement()
	_travel(3)
	_update_flight(2.5)
	await _capture_frame("flight")
	print("GALLERY_COMPLETE; draw calls: ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"; objects: ",Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	_finish_quit()

func _capture_frame(label:String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("res://captures/"+label+".png")

func _tangent(up:Vector3, preferred:Vector3) -> Vector3:
	var projected = preferred - up*preferred.dot(up)
	if projected.length_squared() < 0.000001:
		var reference = Vector3.RIGHT if absf(up.x) < 0.8 else Vector3.FORWARD
		projected = reference-up*reference.dot(up)
	return projected.normalized()

func _decoration_radius(kind:int) -> float:
	return Catalog.RADII[clampi(kind,0,ITEMS.size()-1)]

func _placement_issue(n:Vector3) -> String:
	var footprint = _decoration_radius(selected)
	if worlds[0].has_method("placement_issue"):
		var terrain_issue:String = worlds[0].placement_issue(n,footprint)
		if not terrain_issue.is_empty():
			return terrain_issue
	for entry in placed:
		if n.distance_to(Vector3(entry.n[0],entry.n[1],entry.n[2]))*RADII[0] < footprint+_decoration_radius(int(entry.kind))+0.15:
			return "Give this little object a bit more breathing room."
	for obstacle in worlds[0].obstacles:
		if n.distance_to(obstacle.normal)*RADII[0] < float(obstacle.radius)+footprint+0.15:
			return "Find a clear patch away from the garden and buildings."
	for key in worlds[0].anchors:
		if n.distance_to(worlds[0].anchors[key])*RADII[0] < 1.65:
			return "Let's keep the landing pad and paths clear."
	return ""

func _make_exhaust(parent:Node3D) -> void:
	var particles = CPUParticles3D.new()
	particles.amount = 40
	particles.lifetime = 0.75
	particles.local_coords = false
	particles.direction = Vector3.DOWN
	particles.spread = 12
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 3.5
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.2
	var gradient = Gradient.new()
	gradient.set_color(0,Color(0.8,0.95,1.0,0.8))
	gradient.add_point(0.4,Color(0.4,0.8,1.0,0.45))
	gradient.set_color(gradient.get_point_count()-1,Color(0.6,0.8,1.0,0))
	particles.color_ramp = gradient
	var mesh = SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	mesh.radial_segments = 8
	mesh.rings = 4
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	particles.mesh = mesh
	parent.add_child(particles)
	particles.position.y = -0.02

func _reel() -> void:
	hud.toast("")
	await get_tree().create_timer(0.5).timeout
	Input.action_press("move_left")
	await get_tree().create_timer(0.7).timeout
	Input.action_press("run")
	await get_tree().create_timer(1.3).timeout
	Input.action_release("run")
	Input.action_release("move_left")
	hop_speed = 4.3
	audio.play_cue("jump")
	await get_tree().create_timer(1.0).timeout
	_travel(1)
	await get_tree().create_timer(5.5).timeout
	normal = (_anchor(1,"neighbor",Vector3.UP)+Vector3(0,0,0.20)).normalized()
	_update_player(0)
	_talk(0)
	await get_tree().create_timer(2.5).timeout
	print("REEL_COMPLETE")
	_finish_quit()

func _quest_token(quest:int, token:String="") -> Node3D:
	var root = Node3D.new()
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("ffd76d") if quest == 0 else Color("dd8e55")
	material.metallic = 0.25 if quest == 0 else 0.65
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 0.6 if quest == 0 else 0.12
	if token.contains("seed"):
		material.albedo_color = Color("d2b189")
		material.emission = Color("9fe5aa")
		Art._ball(root,"Moonbean",Vector3(0,0.24,0),Vector3(0.28,0.40,0.25),material)
		var leaf_mat = Art._material(Color("82c69a"))
		Art._rod(root,"Sprout",Vector3(0,0.37,0),Vector3(0.03,0.57,0),0.014,leaf_mat)
		var leaf = Art._ball(root,"FirstLeaf",Vector3(0.10,0.52,0),Vector3(0.20,0.07,0.11),leaf_mat)
		leaf.rotation.z = 0.4
	elif token.contains("gear"):
		material.albedo_color = Color("d6aa60")
		material.emission = material.albedo_color
		var ring = TorusMesh.new()
		ring.inner_radius = 0.09
		ring.outer_radius = 0.23
		ring.rings = 32
		ring.ring_segments = 8
		Art._mesh(root,"GearHub",ring,Vector3(0,0.22,0),material)
		for tooth in range(10):
			var angle = tooth*TAU/10.0
			var mesh = BoxMesh.new()
			mesh.size = Vector3(0.085,0.095,0.085)
			var node = Art._mesh(root,"Tooth",mesh,Vector3(sin(angle)*0.23,0.22,cos(angle)*0.23),material)
			node.rotation.y = angle
	elif token.contains("crystal"):
		material.albedo_color = Color("a3efd8") if token.contains("crystal") else Color("e7bc76")
		material.emission = material.albedo_color
		var mesh = MeshInstance3D.new()
		var gem = PrismMesh.new()
		gem.size = Vector3(0.27,0.53,0.27)
		mesh.mesh = gem
		mesh.material_override = material
		mesh.position.y = 0.29
		mesh.rotation_degrees.z = 12
		root.add_child(mesh)
	elif quest == 0:
		Art._star(root,Vector3(0,0.32,0),0.28,material)
	else:
		for i in range(5):
			var ring = MeshInstance3D.new()
			var torus = TorusMesh.new()
			torus.inner_radius = 0.13
			torus.outer_radius = 0.19
			torus.rings = 24
			torus.ring_segments = 8
			ring.mesh = torus
			ring.material_override = material
			ring.position.y = 0.12+i*0.065
			root.add_child(ring)
	var light = OmniLight3D.new()
	light.light_color = material.albedo_color
	light.light_energy = 0.0 if mobile_profile else 0.3
	light.omni_range = 1.3
	light.position.y = 0.3
	root.add_child(light)
	return root

func _choose_conversation_view(neighbor_position:Vector3) -> Vector3:
	var north = _tangent(normal,Vector3.BACK).rotated(normal,orbit)
	var best = north
	var best_score := INF
	for angle in [0.8,-0.8,1.35,-1.35,0.4,-0.4]:
		var back = north.rotated(normal,angle)
		var right = normal.cross(back).normalized()
		var eye = conversation_focus+normal*3.2+back*6.1+right*1.1
		var score = maxf(0.0,0.85-absf(right.dot(neighbor_position-player.global_position)))*10.0
		for obstacle in worlds[current].obstacles:
			if obstacle.get("kind","") == "neighbor":
				continue
			for height in [0.6,1.3,2.0]:
				var point = CENTERS[current]+obstacle.normal*(RADII[current]+height)
				for subject in [player.global_position+normal*0.7,neighbor_position+normal*0.5]:
					var closest = Geometry3D.get_closest_point_to_segment(point,eye,subject)
					var overlap = float(obstacle.radius)+0.7-point.distance_to(closest)
					if overlap > 0:
						score += overlap*12.0
		if score < best_score:
			best_score = score
			best = back
	return best

func _update_neighbors(delta:float) -> void:
	for i in range(neighbors.size()):
		var neighbor:Node3D = neighbors[i]
		var engaged = not flight and current == NEIGHBOR_PLANETS[i] and conversation and hud.is_panel_open()
		neighbor_motions[i].animate(elapsed,delta,engaged)
		if not flight and current == NEIGHBOR_PLANETS[i] and neighbor.global_position.distance_to(player.global_position) < 4.5:
			var up = neighbor.position.normalized()
			var direction = _tangent(up,player.global_position-neighbor.global_position)
			var look = Basis(up.cross(direction).normalized(),up,direction)
			neighbor.quaternion = neighbor.quaternion.slerp(look.get_rotation_quaternion(),1.0-exp(-delta*2.5))
