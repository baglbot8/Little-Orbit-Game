extends "res://tests/integration.gd"
## Independent regression, run only AFTER parent freeze:
## godot --headless --path . --script res://tests/mobile_neighbors_checks.gd -- --integration --mobile-neighbors --touch-test
## Only unique /tmp fixtures use allow_test. Never reads/writes player saves.
const PLANETS := [1, 2, 4, 5]
const PEOPLE := ["Lumi", "Bolt", "Pip", "Miso"]
const STATE_FIELDS := ["favors", "friendship", "cargo", "quest_round", "quest_progress", "collected_bits", "talk_counts"]
var helper: RefCounted

func _press(prefix: String, scope: Node = null) -> bool:
	# Mobile profile intentionally hides the desktop footer. Exercise the real
	# touch Map hit region instead of looking for that hidden desktop button.
	if prefix == "Map" and scope == null and is_instance_valid(game.touch_controls):
		game._sync_touch()
		var touch: Node = game.touch_controls
		if touch.is_touch_enabled() and touch.visible:
			var finger := InputEventScreenTouch.new()
			finger.index = 20
			finger.position = touch._buttons.map.get_center()
			finger.pressed = true
			touch._unhandled_input(finger)
			finger.pressed = false
			touch._input(finger)
			return _check(game.hud.is_panel_open(), "live touch Map opens the destination panel")
	return super._press(prefix, scope)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--integration" in args or not "--mobile-neighbors" in args or not "--touch-test" in args:
		printerr("MOBILE_REFUSED: requires --integration --mobile-neighbors --touch-test")
		quit(2)
		return
	for forbidden in ["--smoke-test", "--capture", "--gallery", "--reel"]:
		if forbidden in args:
			quit(2)
			return
	root.size = Vector2i(1280, 800)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	if not _check(game.test_mode and game.hud != null and game.audio != null, "main initialization completed with HUD/audio in save-free mode"):
		game.queue_free()
		quit(1)
		return
	helper = load("res://tests/polish_checks.gd").new()
	helper.r = self
	helper.game = game
	if _check(game.test_mode and game.worlds.size() == 6 and game.neighbors.size() == 4, "save-free six-world/four-neighbor startup"):
		_identity()
		await _migration()
		await helper._load_fixture({"version":1}, "mobile-fresh")
		for who in [2, 3]:
			await _six_rounds(who)
		await _touch_locks()
	for action in ["move_left", "move_right", "move_up", "move_down", "run", "hop"]:
		Input.action_release(action)
	game.audio.stop_all()
	game.queue_free()
	await process_frame
	await process_frame
	print("MOBILE_NEIGHBORS_RESULT: %d checks, %d failures" % [checks, failures.size()])
	for evidence in failures:
		printerr("MOBILE_EVIDENCE: " + evidence)
	quit(0 if failures.is_empty() else 1)

func _identity() -> void:
	_check(game.NAMES == ["Clover", "Luma", "Rust", "The Commons", "Pebble", "Honey"], "stable planet IDs 0–5 preserve old Commons ID 3")
	_check(game.NEIGHBOR_NAMES == PEOPLE and game.NEIGHBOR_PLANETS == PLANETS, "stable NPC IDs 0–3 map to worlds 1,2,4,5")
	for who in range(4):
		_check(game.neighbors[who].get_parent() == game.worlds[PLANETS[who]], "%s scene parent is correct planet" % PEOPLE[who])
		for field in STATE_FIELDS:
			_check(game.get(field).size() == 4 and not game.get(field)[who], "%s has fresh %s" % [PEOPLE[who], field])
	var entries: Array = game._journal_entries()
	if _check(entries.size() == 5, "journal has four neighbor rows plus home"):
		for who in range(4):
			_check(entries[who].who == who and entries[who].name == PEOPLE[who] and entries[who].location == game.NAMES[PLANETS[who]], "journal preserves identity/location for %s" % PEOPLE[who])

func _migration() -> void:
	var old := {"version":1, "stars":143, "inventory":[3,0,4,2,1,5], "favors":[1,2], "friendship":[3,5], "cargo":[true,false], "quest_round":[3,5], "quest_progress":[1,1], "collected_bits":[0,1], "talk_counts":[17,23], "planet":3, "wishes":7, "placed":[]}
	await helper._load_fixture(old, "mobile-two-neighbor-upgrade")
	for field in STATE_FIELDS:
		_check(game.get(field).slice(0,2) == old[field] and game.get(field).slice(2) == ([false,false] if field == "cargo" else [0,0]), "two-neighbor migration preserves old %s and defaults new slots" % field)
	_check(game.current == 3 and game.stars == 143 and game.wishes == 7 and game.inventory.slice(0,6) == old.inventory, "old Commons/wallet/wishes/inventory survive expansion")
	await helper._reload("mobile-migrated-again")
	_check(game.current == 3 and game.friendship == [3,5,0,0] and game.talk_counts == [17,23,0,0], "migrated state survives scene reconstruction and second load")
	# New IDs must survive actual serialization, not a clamp back to Commons.
	for destination in [4,5]:
		await _fly(destination)
		var before: Vector3 = game.normal
		await helper._reload("mobile-planet-%d" % destination)
		_check(game.current == destination and game.normal.is_equal_approx(before) and _sphere_ok(), "planet %d save/restart restores correct sphere and position" % destination)

func _at_neighbor(who: int) -> void:
	await _fly(PLANETS[who])
	_position_at(game.worlds[PLANETS[who]].anchors.neighbor)
	_key(KEY_E)
	_check(game.hud.is_panel_open() and helper._labels().contains(PEOPLE[who]), "actual travel and E route conversation to %s" % PEOPLE[who])

func _six_rounds(who: int) -> void:
	var untouched: Array = game.friendship.duplicate()
	for round_index in range(6):
		await _at_neighbor(who)
		if round_index > 0:
			_press("Another little favor?")
		var request: Dictionary = game.Neighbourhood.quest(who, round_index)
		if not _check(game.favors[who] == 1 and game.quest_round[who] == round_index, "%s accepts round %d" % [PEOPLE[who], round_index]):
			return
		_check(helper._labels().contains(request.request), "current round request is displayed")
		game.hud.close_panel()
		var count_before: int = game.pickups.size()
		for repeat in range(3):
			game._action("favor%d" % who)
			game._spawn_pickups()
		_check(game.pickups.size() == count_before, "reaccept/spawn cannot stack round %d tokens for %s" % [round_index, PEOPLE[who]])
		game.hud.close_panel()
		match str(request.type):
			"retrieve", "collect":
				await _gather(who, request)
			"decorate":
				await _fly(0)
				game.inventory[0] = maxi(int(game.inventory[0]), int(request.target))
				for slot in range(int(request.target)):
					if game.placed.size() < int(request.target):
						helper._add_home_item()
				game._refresh_favor_progress()
				_check(game.cargo[who], "actual placed home objects satisfy new neighbor")
			"visit":
				_check(not game.cargo[who], "old visits do not complete freshly accepted favor")
				if game.current == int(request.planet):
					await _fly(0 if game.current != 0 else 3)
				await _fly(int(request.planet))
			"wish":
				_check(not game.cargo[who], "previous wishes do not complete fresh favor")
				await _fly(3)
				_position_at(game.worlds[3].anchors.event)
				_key(KEY_E)
				_check(not game.cargo[who], "opening wish panel alone does not grant progress")
				_press("Send a little wish")
			_:
				_check(false, "unknown favor type: " + str(request.type))
		_check(game.cargo[who] and game.quest_progress[who] == int(request.target), "%s round %d reaches exact target" % [PEOPLE[who], round_index])
		await helper._reload("mobile-ready-%d-%d" % [who,round_index])
		_check(game.cargo[who] and game.quest_round[who] == round_index, "new neighbor favor readiness survives save/restart")
		await _fly(PLANETS[who])
		_position_at(game.worlds[PLANETS[who]].anchors.neighbor)
		var wallet: int = game.stars
		var inventory_before: Array = game.inventory.duplicate()
		_key(KEY_E)
		var added := 0
		var valid_delta := true
		for kind in range(game.ITEMS.size()):
			var delta: int = int(game.inventory[kind])-int(inventory_before[kind])
			added += delta
			valid_delta = valid_delta and delta in [0,1]
		_check(game.favors[who] == 2 and not game.cargo[who] and game.friendship[who] == round_index+1 and game.stars == wallet+25 and added == 1 and valid_delta, "%s round %d pays one valid item, 25 stars, one friendship" % [PEOPLE[who],round_index])
		_press("Thank you!")
		_key(KEY_E)
		_check(game.stars == wallet+25 and _inventory_total() == _sum(inventory_before)+1 and game.friendship[who] == round_index+1, "repeat conversation cannot pay twice")
		game.hud.close_panel()
		await helper._reload("mobile-delivered-%d-%d" % [who,round_index])
		_check(game.favors[who] == 2 and _live_pickups(who).is_empty(), "delivered new favor stays complete with no respawn")
	for other in range(4):
		if other != who:
			_check(game.friendship[other] == untouched[other], "six %s favors never reward another neighbor" % PEOPLE[who])
	await _at_neighbor(who)
	_press("Another little favor?")
	_check(game.quest_round[who] == 6 and game.quest_progress[who] == 0, "%s wraps all six rounds with fresh progress" % PEOPLE[who])
	game.hud.close_panel()

func _sum(values: Array) -> int:
	var total := 0
	for value in values:
		total += int(value)
	return total

func _gather(who: int, request: Dictionary) -> void:
	var live := _live_pickups(who)
	if not _check(live.size() == int(request.target), "exact request token count exists"):
		return
	var slots := {}
	var points: Array[Vector3] = []
	for pickup in live:
		_check(not slots.has(pickup.slot) and pickup.planet == int(request.planet), "token has unique slot on requested world")
		slots[pickup.slot] = true
		for point in points:
			_check(point.distance_to(pickup.normal)*game.RADII[pickup.planet] > 0.25, "collect slots do not overlap into a stack")
		points.append(pickup.normal)
	for slot in range(int(request.target)):
		live = _live_pickups(who)
		if not _check(not live.is_empty(), "next uncollected token survives restart"):
			return
		var pickup: Dictionary = live[0]
		await _fly(int(pickup.planet))
		_position_at(pickup.normal)
		_key(KEY_E)
		_key(KEY_E)
		game._spawn_pickups()
		_check(game.quest_progress[who] == slot+1 and _live_pickups(who).size() == int(request.target)-slot-1, "double Use gathers exactly one unique token")
		await helper._reload("mobile-partial-%d-%d" % [who,slot])
		_check(game.quest_progress[who] == slot+1 and _live_pickups(who).size() == int(request.target)-slot-1, "partial collection persists without respawning collected slot")

func _touch_locks() -> void:
	var controls: Node = null
	for node in game.get_children():
		if node.has_method("release_inputs") and node.has_method("set_game_state"):
			controls = node
	if not _check(controls != null, "live main owns touch controls"):
		return
	await _fly(0)
	game.hud.close_panel()
	game._process(1.0/60.0)
	_check(controls.is_touch_enabled(), "touch-test enables live controls")
	for lock in ["map", "pause", "conversation", "flight", "focus"]:
		game.hud.close_panel()
		if lock == "conversation":
			await _fly(5)
			_position_at(game.worlds[5].anchors.neighbor)
		game._process(1.0/60.0)
		var finger := InputEventScreenTouch.new()
		finger.index = 7
		finger.pressed = true
		finger.position = controls._center + Vector2(controls._radius*0.8,0)
		controls._unhandled_input(finger)
		_check(Input.is_action_pressed("move_right"), lock+": touch stick owns movement before lock")
		var run_finger := InputEventScreenTouch.new()
		run_finger.index = 8
		run_finger.pressed = true
		run_finger.position = controls._buttons.run.get_center()
		controls._unhandled_input(run_finger)
		_check(Input.is_action_pressed("run"), lock+": touch Run is held before lock")
		if lock == "flight":
			game._travel(4)
		elif lock == "focus":
			controls._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		elif lock == "conversation":
			game._touch_action("interact")
			_check(game.conversation and game.hud.is_panel_open(), "touch Use opens Miso conversation")
		else:
			game._touch_action(lock)
		game._process(1.0/60.0)
		_check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("run") and controls._owners.is_empty(), lock+": transition clears held touch input and ownership")
		if lock != "focus":
			controls._unhandled_input(finger)
			_check(not Input.is_action_pressed("move_right"), lock+": hidden controls cannot recapture touch")
		finger.pressed = false
		controls._input(finger)
		run_finger.pressed = false
		controls._input(run_finger)
		for frame in range(301):
			if game.flight:
				game._process(1.0/60.0)
		game.hud.close_panel()
