extends SceneTree
## Run: godot --headless --path . --script res://tests/integration.gd -- --integration
## Nonfatal assertions retain independent critic evidence; any failure exits 1.
## UI buttons emit their real pressed signals. Input events enter main's input
## handler directly, avoiding headless viewport focus; walking uses Input state.
## Main's process is stepped deterministically after real ready frames.

var game: Node
var failures: Array[String] = []
var checks := 0
var roundtrip_path := "/tmp/little-orbit-integration-%d.json" % OS.get_process_id()

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, evidence: String) -> bool:
	checks += 1
	if not condition:
		failures.append(evidence)
		printerr("CRITIC_ASSERTION: " + evidence)
	return condition

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--integration" in args or "--smoke-test" in args or "--capture" in args or "--gallery" in args or "--reel" in args:
		printerr("Use -- --integration only; refusing save-enabled or automatic smoke/capture execution.")
		quit(2)
		return
	var polish_script = load("res://tests/polish_checks.gd")
	if not _check(polish_script != null and polish_script.can_instantiate(), "polish checks compile before gameplay execution"):
		quit(1)
		return
	var scene := load("res://main.tscn") as PackedScene
	if not _check(scene != null, "main.tscn loads"):
		quit(1)
		return
	root.size = Vector2i(1280, 800)
	game = scene.instantiate()
	root.add_child(game)
	# Headless scene construction can exceed the real-time toast duration in
	# its first frame. Hold that timer until the pointer checks consume it.
	if game.hud != null:
		game.hud._toast_timer.paused = true
	await process_frame
	await process_frame
	if not _check(game.get("test_mode") == true, "main enables save-free integration test_mode"):
		game.queue_free()
		quit(1)
		return
	game.set_process(false)
	if not _check(game.worlds.size() == 6 and game.neighbors.size() == 4 and game.hud != null, "ready constructs six worlds, four neighbors and HUD"):
		quit(1)
		return
	_check(game.favors == [0, 0,0,0] and game.cargo == [false, false,false,false] and game.placed.is_empty(), "integration starts with fresh quest and decoration state")
	var polish = polish_script.new()
	if "--polish-retained" in args:
		print("INTEGRATION_SCOPE: sticky shop and journal grammar only")
		game.hud._toast_timer.paused = false
		await polish.run_retained(self)
	else:
		await _pointer_gui()
		game.hud._toast_timer.paused = false
		await _quests()
		await _repeat_favor()
		await _fly(3)
		_shop()
		await _fly(0)
		_decorations()
		_terrain_placement()
		await process_frame
		await _movement()
		await _running()
		_character_colors()
		_persistence()
		await polish.run(self)
	for action in ["move_left", "move_right", "move_up", "move_down", "hop", "run"]:
		Input.action_release(action)
	var owned_nodes: Array[WeakRef] = [weakref(game), weakref(game.audio)]
	for node in game.audio.get_children():
		owned_nodes.append(weakref(node))
	game.queue_free()
	await process_frame
	await process_frame
	var released := true
	for reference in owned_nodes:
		released = released and reference.get_ref() == null
	_check(released, "game and audio player nodes are released after teardown")
	print("INTEGRATION_RESULT: %d checks, %d failures" % [checks, failures.size()])
	for evidence in failures:
		printerr("CRITIC_EVIDENCE: " + evidence)
	quit(0 if failures.is_empty() else 1)

func _press(prefix: String, scope: Node = null) -> bool:
	var parent: Node = game.hud if scope == null else scope
	for node in parent.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text.begins_with(prefix) and button.is_visible_in_tree() and not button.disabled:
			# First dialogue activation reveals the voiced text; next chooses.
			var was_typing: bool = game.hud.get("_typing") == true
			button.pressed.emit()
			if was_typing and is_instance_valid(button) and button.is_visible_in_tree() and game.hud.get("_typing") == false:
				button.pressed.emit()
			return true
	return _check(false, "visible enabled UI button exists: " + prefix)

func _decor_button(kind: int) -> Button:
	# The card title identifies the item; its concise Place button need not
	# repeat the potentially long object name. This also serves controller focus.
	for card in game.hud.find_children("Decor*", "PanelContainer", true, false):
		var matches := false
		for label in card.find_children("*", "Label", true, false):
			matches = matches or label.text == game.ITEMS[kind]
		if matches:
			for node in card.find_children("*", "Button", true, false):
				if node.is_visible_in_tree() and node.tooltip_text.begins_with("Place " + game.ITEMS[kind]):
					return node
	return null

func _press_decor(kind: int) -> bool:
	var button := _decor_button(kind)
	if not _check(button != null and not button.disabled, "enabled Place action belongs to item card: " + game.ITEMS[kind]):
		return false
	button.pressed.emit()
	return true

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_input(event)

func _click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	game._unhandled_input(event)

func _inventory_total() -> int:
	var total := 0
	for count in game.inventory:
		total += int(count)
	return total

func _position_at(n: Vector3) -> void:
	game.hud.close_panel()
	game.normal = n.normalized()
	game.velocity = Vector3.ZERO
	game.hop = 0.0
	game.hop_speed = 0.0
	game.facing = n.cross(Vector3.UP).normalized() if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.BACK
	game._update_player(0.0)
	game._update_camera(1.0)

func _fly(destination: int) -> void:
	if game.current == destination:
		return
	game.hud.close_panel()
	_press("Map")
	_check(game.hud.is_panel_open(), "map button opens destination panel")
	var here_disabled := false
	for node in game.hud.find_children("*", "Button", true, false):
		if node.text.contains("You are here") and node.is_visible_in_tree():
			here_disabled = node.disabled
	_check(here_disabled, "current destination is disabled")
	if not _press("Visit " + ("Commons" if destination == 3 else game.NAMES[destination])):
		return
	if not _check(game.flight and not game.player.visible and not game.hud.is_panel_open(), "destination signal starts flight and closes map"):
		return
	var target: int = game.flight_target
	game.hud.travel_requested.emit((destination + 1) % 6)
	_check(game.flight_target == target, "second travel signal cannot redirect active flight")
	var stable := true
	for frame in range(301):
		if game.flight:
			game._process(1.0 / 60.0)
			stable = stable and game.camera.global_transform.is_finite()
			if game.flight:
				stable = stable and game.ship.global_transform.is_finite()
	_check(stable, "flight transforms stay finite to planet %d" % destination)
	_check(not game.flight and game.current == destination and game.player.visible, "flight arrives on planet %d" % destination)
	game._update_player(0.0)
	_check(_sphere_ok(), "arrival is on destination sphere %d" % destination)
	await process_frame

func _quests() -> void:
	for who in range(2):
		await _fly(who + 1)
		_position_at(game.worlds[who + 1].anchors["neighbor"])
		_key(KEY_E)
		_check(game.favors[who] == 1 and game.hud.is_panel_open(), "nearby neighbor %d interaction starts favor" % who)
		_press("I'll find it!")
		_key(KEY_E)
		_check(game.favors[who] == 1, "talk without collectible keeps favor pending %d" % who)
		game.hud.close_panel()
	for who in range(2):
		await _fly(0 if who == 0 else 3)
		var pickup: Dictionary = {}
		for entry in game.pickups:
			if entry.quest == who:
				pickup = entry
		if not _check(not pickup.is_empty(), "collectible exists for quest %d" % who):
			continue
		_position_at(pickup.normal)
		_key(KEY_E)
		_check(game.cargo[who], "nearby interaction gathers collectible %d" % who)
		await process_frame
		_check(not is_instance_valid(pickup.node), "gathered collectible %d leaves scene" % who)
		await _fly(who + 1)
		_position_at(game.worlds[who + 1].anchors["neighbor"])
		var stars_before: int = game.stars
		var items_before := _inventory_total()
		_key(KEY_E)
		_check(game.favors[who] == 2 and not game.cargo[who], "neighbor %d completes favor and consumes cargo" % who)
		_check(game.stars == stars_before + 25 and _inventory_total() == items_before + 1, "neighbor %d awards exactly 25 stars and one item" % who)
		_press("Thank you!")
		_key(KEY_E)
		_check(game.stars == stars_before + 25 and _inventory_total() == items_before + 1, "neighbor %d cannot award twice" % who)
		game.hud.close_panel()
	await _fly(3)

func _shop() -> void:
	_position_at(game.worlds[3].anchors["shop"])
	var stars_before: int = game.stars
	var items_before := _inventory_total()
	_key(KEY_E)
	_press("Buy a parcel")
	_check(game.stars == stars_before - 15 and _inventory_total() == items_before + 1, "shop UI purchase costs 15 and adds one item")
	# Controlled insufficient-funds fixture, restored after this independent case.
	var saved_stars: int = game.stars
	game.stars = 14
	var inventory_before: Array = game.inventory.duplicate()
	_key(KEY_E)
	var disabled_parcel := false
	for node in game.hud.find_children("*", "Button", true, false):
		if node.text.begins_with("Buy a parcel") and node.is_visible_in_tree():
			disabled_parcel = node.disabled
	_check(disabled_parcel, "shop disables unaffordable parcel at 14 stardust")
	game._action("buy")
	_check(game.stars == 14 and game.inventory == inventory_before, "insufficient funds preserve wallet and inventory")
	game.hud.close_panel()
	game.stars = saved_stars
	game._update_status()

func _aim_placement(target: Vector3) -> void:
	# Invert the 1.25-unit placement offset while keeping facing tangent.
	var tangent := target.cross(Vector3.UP).normalized()
	if tangent.length_squared() < 0.1:
		tangent = Vector3.RIGHT
	var angle := atan(1.25 / float(game.RADII[0]))
	_position_at(target * cos(angle) - tangent * sin(angle))
	game.facing = target * sin(angle) + tangent * cos(angle)

func _choose_decor() -> void:
	_press("Decorate")
	_press_decor(0)
	_check(game.selected == 0 and is_instance_valid(game.preview), "inventory button creates selected decoration preview")

func _decorations() -> void:
	var original: Array = game.inventory.duplicate()
	var total: int = _inventory_total() + game.placed.size()
	_choose_decor()
	var clear_target := _valid_ground()
	if not _check(clear_target != Vector3.ZERO, "a valid ground fixture exists for successful placement"):
		game._cancel_placement()
		return
	_aim_placement(clear_target)
	_preview_state(true, "clear ground")
	_key(KEY_R)
	_click()
	if not _check(game.placed.size() == 1 and game.inventory[0] == original[0] - 1, "clear patch placement consumes exactly one selected item"):
		game._cancel_placement()
		return
	_check(game.selected == -1 and game.placed_nodes.size() == 1, "placement commits scene node and clears selection")
	_check(is_equal_approx(float(game.placed[0].angle), PI / 4.0), "rotate input is retained in placed decoration")
	_choose_decor()
	_preview_state(false, "overlapping decoration")
	_click()
	_check(game.placed.size() == 1 and _inventory_total() + game.placed.size() == total, "overlapping decoration is rejected without inventory loss")
	game._cancel_placement()
	for anchor in game.worlds[0].anchors.values():
		_aim_placement(anchor)
		_choose_decor()
		_preview_state(false, "anchor interior")
		_click()
		_check(game.placed.size() == 1 and _inventory_total() + game.placed.size() == total, "anchor collision rejects placement at %s" % anchor)
		game._cancel_placement()
	for obstacle in game.worlds[0].obstacles:
		_aim_placement(obstacle.normal)
		_choose_decor()
		_preview_state(false, "obstacle interior")
		_click()
		_check(game.placed.size() == 1 and _inventory_total() + game.placed.size() == total, "obstacle collision rejects placement at %s" % obstacle.normal)
		game._cancel_placement()
	_position_at(clear_target)
	_key(KEY_X)
	_check(game.placed.is_empty() and game.placed_nodes.is_empty() and game.inventory == original, "remove input restores exact inventory and removes placed node")
	_key(KEY_X)
	_check(game.inventory == original, "repeated removal cannot duplicate inventory")

func _sphere_ok() -> bool:
	var radius: float = game.RADII[game.current] + 0.04 + game.hop
	return game.normal.is_finite() and absf(game.normal.length() - 1.0) < 0.001 and absf(game.player.position.distance_to(game.CENTERS[game.current]) - radius) < 0.002

func _basis_ok(node: Node3D) -> bool:
	var basis := node.global_basis
	return node.global_transform.is_finite() and absf(basis.determinant() - 1.0) < 0.01 and absf(basis.x.dot(basis.y)) < 0.01 and absf(basis.y.dot(basis.z)) < 0.01

func _movement() -> void:
	# All 26 axis/edge/corner directions include both poles on every axis.
	# Additional deterministic Fibonacci samples exercise the rest of the sphere.
	var normals: Array[Vector3] = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				if Vector3(x, y, z) != Vector3.ZERO:
					normals.append(Vector3(x, y, z).normalized())
	for i in range(32):
		var y := 1.0 - 2.0 * (i + 0.5) / 32.0
		var r := sqrt(1.0 - y * y)
		normals.append(Vector3(cos(i * 2.399963) * r, y, sin(i * 2.399963) * r))
	for planet in range(6):
		await _fly(planet)
		for n in normals:
			_position_at(n)
			var stable := _sphere_ok() and _basis_ok(game.player) and _basis_ok(game.camera)
			# A tangent fallback must also work when facing is parallel to normal.
			game.facing = n
			game._update_player(0.0)
			_check(_basis_ok(game.player), "parallel-facing tangent fallback: planet %d normal %s player determinant %.6f" % [planet, n, game.player.global_basis.determinant()])
			_position_at(n)
			_key(KEY_SPACE)
			var rose := false
			for frame in range(90):
				game._process(1.0 / 60.0)
				rose = rose or game.hop > 0.1
				stable = stable and _sphere_ok() and _basis_ok(game.player) and _basis_ok(game.camera)
			_check(rose and game.hop == 0.0, "hop rises and lands: planet %d normal %s" % [planet, n])
			var moved := false
			for action in ["move_up", "move_right", "move_down", "move_left"]:
				var before: Vector3 = game.normal
				Input.action_press(action)
				for frame in range(12):
					game._process(1.0 / 60.0)
					stable = stable and _sphere_ok() and _basis_ok(game.player) and _basis_ok(game.camera)
				Input.action_release(action)
				moved = moved or before.distance_to(game.normal) > 0.001
			_check(moved, "walk input moves on planet %d normal %s" % [planet, n])
			_check(stable, "sphere and orthonormal player/camera remain stable: planet %d normal %s" % [planet, n])
		_position_at(Vector3.DOWN)
		_press("Map")
		var before: Vector3 = game.normal
		Input.action_press("move_up")
		_key(KEY_SPACE)
		for frame in range(30):
			game._process(1.0 / 60.0)
		Input.action_release("move_up")
		_check(game.normal.distance_to(before) < 0.0001 and game.hop == 0.0, "open UI blocks walking and hop on planet %d" % planet)
		game.hud.close_panel()

func _live_pickups(who: int) -> Array:
	var result: Array = []
	for pickup in game.pickups:
		if pickup.quest == who and is_instance_valid(pickup.node) and not pickup.node.is_queued_for_deletion():
			result.append(pickup)
	return result

func _repeat_favor() -> void:
	_check(game.favors == [2, 2,0,0], "repeat favor begins after both original favors complete")
	# Round 1 is three crystals on each neighbor's OWN planet, not a repeat
	# of round 0's single off-world star/coil. Use the real conversation button.
	for who in range(2):
		await _fly(who + 1)
		_position_at(game.worlds[who + 1].anchors["neighbor"])
		var stars_before: int = game.stars
		var items_before := _inventory_total()
		var friendship_before: Array = game.friendship.duplicate()
		_key(KEY_E)
		_press("Another little favor?")
		_check(game.favors[who] == 1 and game.favors[1-who] == 2 and not game.cargo[who] and game.quest_round[who] == 1, "round 1 acceptance resets only neighbor %d" % who)
		_check(_live_pickups(who).size() == 3 and _live_pickups(1-who).is_empty(), "round 1 spawns three unique crystals for neighbor %d" % who)
		var pickup_count: int = game.pickups.size()
		for repeat in range(3):
			game._action("favor%d" % who)
			game._spawn_pickups()
		_check(game.pickups.size() == pickup_count and _live_pickups(who).size() == 3, "pending favor and spawn calls cannot duplicate round 1 crystals")
		_check(game.stars == stars_before and _inventory_total() == items_before and game.friendship == friendship_before, "restarting favor grants no premature reward")
		game.hud.close_panel()
		var live := _live_pickups(who)
		if not _check(live.size() == 3, "round 1 has three collectibles to gather"):
			return
		var gathered := 0
		for pickup in live:
			_check(pickup.planet == who + 1 and pickup.round == 1 and pickup.title.contains("crystal"), "round 1 crystal is on the requested neighbor planet")
			_position_at(pickup.normal)
			_key(KEY_E)
			gathered += 1
			_key(KEY_E)
			game._spawn_pickups()
			_check(game.quest_progress[who] == gathered and game.cargo[who] == (gathered == 3), "round 1 progress %d/3; repeated gather cannot double-count" % gathered)
			_check(_live_pickups(who).size() == 3-gathered, "only uncollected crystal slots remain")
			await process_frame
			_check(not is_instance_valid(pickup.node), "collected crystal is freed")
			_position_at(game.worlds[who + 1].anchors["neighbor"])
			if gathered < 3:
				_key(KEY_E)
				_check(game.favors[who] == 1 and game.stars == stars_before and _inventory_total() == items_before, "partial collection cannot complete or reward favor")
				game.hud.close_panel()
		_key(KEY_E)
		stars_before += 25
		items_before += 1
		friendship_before[who] += 1
		_check(game.favors == [2, 2,0,0] and not game.cargo[who], "round 1 delivery completes and consumes cargo")
		_check(game.stars == stars_before and _inventory_total() == items_before and game.friendship == friendship_before, "repeat delivery awards exactly 25 stars, one item and one friendship")
		_press("Thank you!")
		_key(KEY_E)
		game._spawn_pickups()
		_check(game.stars == stars_before and _inventory_total() == items_before and game.friendship == friendship_before, "completed repeat favor cannot pay twice")
		_check(_live_pickups(0).is_empty() and _live_pickups(1).is_empty(), "completed quests do not respawn collectibles")
		game.hud.close_panel()

func _persistence() -> void:
	# Data-loader contract: _ready creates scene nodes after loading. This fixture
	# tests serialized state, not live scene reconstruction by _load_game.
	if not _check(not FileAccess.file_exists(roundtrip_path) and not FileAccess.file_exists(roundtrip_path + ".tmp"), "isolated roundtrip paths are unused"):
		return
	var expected := {
		"stars": 137, "inventory": [3, 0, 4, 2, 1, 5, 1, 2, 0, 4, 2, 3, 0, 1, 5, 0, 2, 1],
		"favors": [1, 2, 0, 0], "friendship": [4, 7, 0, 0], "cargo": [true, false, false, false],
		"quest_round": [1, 5, 0, 0], "quest_progress": [3, 1, 0, 0], "collected_bits": [7, 1, 0, 0],
		"talk_counts": [12, 19, 0, 0], "wishes": 4, "overview": true,
		"placed": [
			{"kind": 0, "n": [0.0, -1.0, 0.0], "angle": 0.25},
			{"kind": 4, "n": [1.0, 0.0, 0.0], "angle": 0.75}],
		"suit": 5, "muted": true, "current": 2,
		"normal": Vector3(0.3, -0.8, 0.5).normalized()
	}
	var original: Dictionary = {}
	for field in expected:
		var value = game.get(field)
		original[field] = value.duplicate(true) if value is Array else value
		var fixture = expected[field]
		game.set(field, fixture.duplicate(true) if fixture is Array else fixture)
	# Explicit isolated paths even when checking default allow_test=false guards.
	_check(game._save_game(roundtrip_path), "test_mode save guard returns nonfailure without writing")
	_check(not FileAccess.file_exists(roundtrip_path) and not FileAccess.file_exists(roundtrip_path + ".tmp"), "test_mode blocks saving without explicit allow_test")
	game._save_game(roundtrip_path, true)
	if _check(FileAccess.file_exists(roundtrip_path), "allow_test writes the isolated roundtrip save"):
		var disk = JSON.parse_string(FileAccess.get_file_as_string(roundtrip_path))
		_check(disk is Dictionary and disk.get("version") == 1, "roundtrip save is versioned JSON")
		_check(not FileAccess.file_exists(roundtrip_path + ".tmp"), "atomic save leaves no staging file")
		var bytes_before := FileAccess.get_file_as_string(roundtrip_path)
		# A directory at the staging filename fails deterministically without
		# depending on OS permission behavior or touching any player-save path.
		if _check(DirAccess.make_dir_absolute(roundtrip_path+".tmp") == OK, "isolated staging obstruction created"):
			_check(not game._save_game(roundtrip_path,true), "failed staging open returns false")
			_check(FileAccess.get_file_as_string(roundtrip_path) == bytes_before, "failed save preserves existing destination byte-for-byte")
			_check(DirAccess.remove_absolute(roundtrip_path+".tmp") == OK, "isolated staging obstruction removed")
		_check(not game._save_game(roundtrip_path+"/missing-parent/save.json",true), "non-directory parent save path returns false")
		_check(FileAccess.get_file_as_string(roundtrip_path) == bytes_before, "bad-parent save failure preserves the valid save")
		game.stars = 1
		game.inventory = [0, 0, 0, 0, 0, 0]
		game.favors = [0, 0,0,0]
		game.friendship = [0, 0,0,0]
		game.cargo = [false, true,false,false]
		game.placed = [{"kind": 5, "n": [0.0, 1.0, 0.0], "angle": 1.5}]
		game.quest_round = [0, 0,0,0]
		game.quest_progress = [0, 0,0,0]
		game.collected_bits = [0, 0,0,0]
		game.talk_counts = [0, 0,0,0]
		game.wishes = 0
		game.overview = false
		game.suit = 0
		game.muted = false
		game.current = 0
		game.normal = Vector3.UP
		game._load_game(roundtrip_path)
		_check(game.stars == 1 and game.placed.size() == 1 and game.current == 0, "test_mode blocks loading without explicit allow_test")
		for attempt in range(2):
			game._load_game(roundtrip_path, true)
			for field in expected:
				var actual = game.get(field)
				var matches: bool = actual.is_equal_approx(expected[field]) if field == "normal" else actual == expected[field]
				if field == "placed":
					# Loader now canonicalizes kind IDs to integers and surface normals.
					matches = JSON.stringify(actual) == JSON.stringify(expected[field])
				_check(matches, "roundtrip load %d restores %s" % [attempt + 1, field])
			_check(game.placed.size() == 2, "roundtrip load %d replaces placed records without duplication" % (attempt + 1))
	for field in original:
		game.set(field, original[field])
	for path in [roundtrip_path, roundtrip_path + ".tmp"]:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(path) == OK, "remove isolated persistence file: " + path)
	_check(not FileAccess.file_exists(roundtrip_path) and not FileAccess.file_exists(roundtrip_path + ".tmp"), "roundtrip files are removed after assertions")

func _valid_ground() -> Vector3:
	# Search only success fixtures. Rejection fixtures stay fixed in visible
	# pond/path interiors, independent of the implementation's verdict.
	for i in range(256):
		var y := 1.0 - 2.0 * (i + 0.5) / 256.0
		var r := sqrt(1.0 - y * y)
		var candidate := Vector3(cos(i * 2.399963) * r, y, sin(i * 2.399963) * r)
		if game._placement_issue(candidate).is_empty():
			return candidate
	return Vector3.ZERO

func _preview_state(valid: bool, label: String) -> void:
	game._update_preview()
	if not _check(is_instance_valid(game.preview) and game.preview_material != null, label + ": preview exists"):
		return
	var color: Color = game.preview_material.albedo_color
	_check((color.g > color.r if valid else color.r > color.g) and color.a > 0.0, label + ": preview shows " + ("valid green" if valid else "invalid red"))
	_check(game._placement_issue(game._placement_normal()).is_empty() == valid, label + ": validator matches expected preview validity")
	_check(game.preview.position.normalized().distance_to(game._placement_normal()) < 0.0001, label + ": preview targets the commit location")

func _terrain_placement() -> void:
	if not _check(game.worlds[0].has_method("placement_issue"), "world exposes pond/path placement masks"):
		return
	var fixtures: Array[Dictionary] = [
		{"label": "north pond center", "normal": Vector3(-0.65, 0.78, -0.35).normalized(), "reason": "pond"},
		{"label": "south pond center", "normal": Vector3(0.3, -0.7, 0.6).normalized(), "reason": "pond"}
	]
	# These positions follow the rendered ribbons from hub to each anchor,
	# not a search for whatever the validator happens to reject.
	for key in game.worlds[0].anchors:
		var destination: Vector3 = game.worlds[0].anchors[key]
		for fraction in [0.35, 0.65]:
			fixtures.append({"label": "path to %s at %.2f" % [key, fraction], "normal": Vector3.UP.slerp(destination, fraction).normalized(), "reason": "path"})
	for fixture in fixtures:
		_aim_placement(fixture.normal)
		_choose_decor()
		var issue: String = game.worlds[0].placement_issue(fixture.normal, 0.0)
		_check(issue.to_lower().contains(fixture.reason), fixture.label + ": terrain interior rejected even with zero footprint")
		_preview_state(false, fixture.label)
		var inventory_before: Array = game.inventory.duplicate()
		var placed_before: Array = game.placed.duplicate(true)
		var nodes_before: Array = game.placed_nodes.duplicate()
		for attempt in range(2):
			_click()
			_check(game.inventory == inventory_before, fixture.label + ": rejected commit consumes no inventory")
			_check(game.placed == placed_before and game.placed_nodes == nodes_before, fixture.label + ": rejected commit adds no record or node")
		_preview_state(false, fixture.label + " after rejection")
		# Move the SAME preview to independently found valid ground. It must
		# become green and commit normally, so invalid state cannot stick.
		var clear_target := _valid_ground()
		if _check(clear_target != Vector3.ZERO, fixture.label + ": valid recovery ground exists"):
			_aim_placement(clear_target)
			_preview_state(true, fixture.label + " moved to clear ground")
			_click()
			_check(game.placed.size() == placed_before.size() + 1 and game.inventory[0] == inventory_before[0] - 1, fixture.label + ": green preview commits exactly one item")
			_position_at(clear_target)
			_key(KEY_X)
			_check(game.inventory == inventory_before and game.placed == placed_before and game.placed_nodes == nodes_before, fixture.label + ": recovery placement removal restores inventory and scene")
		game._cancel_placement()

func _pointer_click(prefix: String) -> bool:
	# Unlike _press, this exercises viewport GUI hit testing and input routing.
	await process_frame
	await process_frame
	var target: Button = null
	for node in game.hud.find_children("*", "Button", true, false):
		if node.text.begins_with(prefix) and node.is_visible_in_tree() and not node.disabled:
			target = node
			break
	if not _check(target != null, "pointer target exists: " + prefix):
		return false
	var rect := target.get_global_rect()
	var point := rect.get_center()
	if not _check(rect.has_area() and root.get_visible_rect().has_point(point), "pointer target center lies in viewport: " + prefix):
		return false
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await process_frame
	return true

func _pointer_gui() -> void:
	# Integration skips the new title screen and its welcome flow. Supply a
	# transient toast explicitly while preserving real GUI routing assertions.
	game.hud.toast("Welcome home, little explorer.")
	_check(game.hud._toast_card.is_visible_in_tree(), "fixture welcome toast is visible before pointer opens modal")
	await _pointer_click("Map")
	if not _check(game.hud.is_panel_open(), "actual footer Map click opens modal through GUI routing"):
		return
	_check(not game.hud._toast_card.is_visible_in_tree(), "opening modal hides welcome toast")
	await _pointer_click("×")
	_check(not game.hud.is_panel_open(), "actual close-button hit dismisses modal")
	_check(not game.hud._toast_card.is_visible_in_tree(), "dismissed modal does not resurrect welcome toast")
	await _pointer_click("Map")
	_check(game.hud.is_panel_open(), "actual footer Map click reopens modal")
	await _pointer_click("Visit Luma")
	if not _check(game.flight and game.flight_target == 1 and not game.hud.is_panel_open(), "actual destination click starts Luma flight and closes modal"):
		game.hud.close_panel()
		return
	var stable := true
	for frame in range(301):
		if game.flight:
			game._process(1.0 / 60.0)
			stable = stable and game.camera.global_transform.is_finite()
	_check(stable and not game.flight and game.current == 1 and game.player.visible, "pointer-selected flight completes with finite camera")
	game._update_player(0.0)
	_check(_sphere_ok(), "pointer-selected flight lands on Luma sphere")
	await process_frame
	await _fly(0)

func _running() -> void:
	_check(InputMap.has_action("run"), "run input exists")
	var mapped := false
	for event in InputMap.action_get_events("run"):
		mapped = mapped or (event is InputEventKey and event.physical_keycode == KEY_SHIFT)
	_check(mapped, "hold Shift is mapped to run")
	await _fly(0)
	# Compare equal-duration movement on a controlled clear patch, then restore scenery.
	var obstacles: Array = game.worlds[0].obstacles
	var decoration_records: Array = game.placed
	game.worlds[0].obstacles = []
	game.placed = []
	var start := Vector3(0,-1,0.3).normalized()
	var distances: Array[float] = []
	for sprint in [false,true]:
		_position_at(start)
		Input.action_press("move_right")
		if sprint:
			Input.action_press("run")
		var traveled := 0.0
		for frame in range(60):
			var before:Vector3 = game.normal
			game._process(1.0/60.0)
			traveled += before.distance_to(game.normal)*game.RADII[0]
		_check(absf(game.velocity.length()-(game.RUN_SPEED if sprint else game.WALK_SPEED)) < 0.03, "walk/run reaches intended speed")
		_check(game.running == sprint, "running state follows Shift plus movement")
		_check(_sphere_ok() and _basis_ok(game.player), "run stays on sphere with valid orientation")
		distances.append(traveled)
		Input.action_release("run")
		for frame in range(30):
			game._process(1.0/60.0)
		_check(not game.running and absf(game.velocity.length()-game.WALK_SPEED)<0.03, "release Shift returns to walk")
		Input.action_release("move_right")
	_check(distances[1]>distances[0]*1.4, "running covers materially more ground than walking")
	Input.action_press("run")
	for frame in range(30):
		game._process(1.0/60.0)
	_check(not game.running and game.velocity.length()<0.01, "Shift alone neither moves nor runs")
	Input.action_press("move_up")
	_key(KEY_SPACE)
	var rose := false
	for frame in range(90):
		game._process(1.0/60.0)
		rose = rose or game.hop>0.1
	_check(rose and game.hop == 0 and _sphere_ok(), "run and hop combine and land safely")
	game.hud.show_travel(0)
	var before:Vector3 = game.normal
	for frame in range(15):
		game._process(1.0/60.0)
	_check(not game.running and game.normal.is_equal_approx(before), "opening a modal immediately stops running")
	game.hud.close_panel()
	game.inventory[0] = maxi(1,int(game.inventory[0]))
	game._start_placement(0)
	for frame in range(40):
		game._process(1.0/60.0)
	_check(not game.running and game.velocity.length()<=game.WALK_SPEED+0.03, "decorating keeps precise walking speed even with Shift")
	game._cancel_placement()
	Input.action_release("run")
	Input.action_release("move_up")
	game.worlds[0].obstacles = obstacles
	game.placed = decoration_records
	# Drive into the home footprint in 100 ms frames to exercise run substeps.
	var home:Vector3 = game.worlds[0].anchors.home
	var obstacle_radius := 0.0
	for obstacle in obstacles:
		if obstacle.normal.is_equal_approx(home):
			obstacle_radius = float(obstacle.radius)
	var approach := (home+Vector3(0,0,0.42)).normalized()
	_position_at(approach)
	Input.action_press("run")
	Input.action_press("move_up")
	var clear := true
	for frame in range(20):
		game._process(0.1)
		clear = clear and game.normal.distance_to(home)*game.RADII[0] >= obstacle_radius+0.16
	_check(clear, "running in slow frames does not enter home collision footprint")
	Input.action_release("run")
	Input.action_release("move_up")
	game.velocity = Vector3.ZERO

func _character_colors() -> void:
	var visor := game.avatar.get_node_or_null("HeadRig/Visor") as MeshInstance3D
	if not _check(visor != null, "refined astronaut retains a separately materialed visor"):
		return
	var glass := visor.material_override
	var colors = [Color("f19b84"),Color("9edbd0"),Color("bba6e3"),Color("dfbf70"),Color("7faad8"),Color("d894ae")]
	for suit in range(6):
		game.suit = suit
		game._apply_suit()
		var accents := 0
		var correct := true
		for mesh in game.avatar.find_children("*","MeshInstance3D",true,false):
			if mesh.get_meta("suit_accent",false):
				accents += 1
				correct = correct and mesh.material_override.albedo_color.is_equal_approx(colors[suit])
		_check(accents>0 and correct, "spacesuit color updates all tagged accent details")
		_check(visor.material_override == glass, "spacesuit changes preserve dark visor and reflections")
