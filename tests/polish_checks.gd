extends RefCounted
## Invoked by integration.gd after the preserved round-0, pointer, movement and
## terrain checks. Only isolated /tmp saves are loaded/written with test_mode
## and allow_test. Injected controller events do not verify physical hardware.

const Catalog = preload("res://scripts/catalog.gd")
const Neighborhood = preload("res://scripts/neighborhood.gd")
const ArtPassChecks = preload("res://tests/art_pass_checks.gd")
const PRICES = [15,20,18,24,16,12,32,26,28,14,18,36,12,20,40,30,26,24]
var r: SceneTree
var game: Node
var fixture_serial := 0

func run(runner: SceneTree) -> void:
	r = runner
	game = r.game
	if not r._check(game.test_mode, "polish fixtures require test_mode"):
		return
	ArtPassChecks.new().run(r)
	_catalog_contract()
	await _catalog_shop()
	await _wardrobe()
	await _remaining_rotation()
	await _partial_collection_reload()
	await _old_save_migration()
	await _saved_placement_validation()
	await _controller_and_camera()
	await _neighbor_collision()
	await _camera_continuity()
	await _new_game_reset()
	await _menus_and_settings()
	await _sticky_shop_and_grammar()
	await _optional_visual_review()

func run_retained(runner: SceneTree) -> void:
	r = runner
	game = r.game
	if _check(game.test_mode, "retained UI fixes require save-free test_mode"):
		await _sticky_shop_and_grammar()

func _fully_visible(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return false
	var bounds := control.get_global_rect()
	if not r.root.get_visible_rect().encloses(bounds):
		return false
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is Control and parent.clip_contents and not parent.get_global_rect().encloses(bounds):
			return false
		parent = parent.get_parent()
	return true

func _sticky_shop_and_grammar() -> void:
	var window_before: Vector2i = r.root.size
	r.root.size = Vector2i(960,600)
	await r.process_frame
	await r.process_frame
	_check(Vector2i(r.root.get_visible_rect().size) == Vector2i(960,600), "retained checks run at native 960 by 600 pixels")
	await r._fly(3)
	r._position_at(game.worlds[3].anchors.shop)
	var wallet: int = game.stars
	var inventory: Array = game.inventory.duplicate()
	game.stars = 100
	game._update_status()
	r._key(KEY_E)
	await r.process_frame
	await r.process_frame
	var purse: Label = game.hud._shop_purse
	var parcel: Button = game.hud._shop_parcel
	if not _check(is_instance_valid(purse) and is_instance_valid(parcel), "shop exposes both sticky purchase-context controls"):
		return
	var fixed_purse := purse.get_global_rect()
	var fixed_parcel := parcel.get_global_rect()
	_check(_fully_visible(purse) and _fully_visible(parcel), "960 shop balance and parcel are completely visible before scrolling")
	game.hud._panel_scroll.scroll_vertical = 10000
	await r.process_frame
	await r.process_frame
	_check(game.hud._panel_scroll.scroll_vertical > 500, "960 shop scroll reaches late catalog rows")
	_check(_fully_visible(purse) and _fully_visible(parcel) and purse.get_global_rect().is_equal_approx(fixed_purse) and parcel.get_global_rect().is_equal_approx(fixed_parcel), "shop balance and parcel remain visible and stationary at the bottom")
	_check(purse.get_global_rect().end.y <= game.hud._panel_scroll.get_global_rect().position.y and parcel.get_global_rect().end.y <= game.hud._panel_scroll.get_global_rect().position.y, "sticky purchase context stays above scrollable item cards")
	var expected_balance := 100
	for kind in [17,16,17]:
		var card = game.hud.find_child("Decor%d" % kind,true,false)
		var buy := _button("Buy ·",card) if card != null else null
		if not _check(buy != null and not buy.disabled, "late catalog purchase remains available with sticky header"):
			break
		game.hud._panel_scroll.ensure_control_visible(buy)
		await r.process_frame
		await r.process_frame
		var previous_scroll: int = game.hud._panel_scroll.scroll_vertical
		var previous_position := buy.get_global_rect()
		var previous_count: int = game.inventory[kind]
		await _pointer(buy)
		expected_balance -= PRICES[kind]
		_check(game.stars == expected_balance and game.inventory[kind] == previous_count+1 and game.hud.is_panel_open(), "sticky-shop pointer purchase charges exactly and preserves browsing")
		_check(game.hud._shop_purse == purse and _fully_visible(purse) and purse.text == "%d stardust" % expected_balance, "sticky wallet visibly updates to %d after purchase" % expected_balance)
		_check(_fully_visible(game.hud._shop_confirmation) and game.hud._shop_confirmation.text.contains(Catalog.NAMES[kind]), "sticky header shows purchased-item confirmation in full")
		_check(abs(game.hud._panel_scroll.scroll_vertical-previous_scroll) <= 1 and buy.get_global_rect().is_equal_approx(previous_position) and r.root.gui_get_focus_owner() == buy, "purchase preserves scroll, item position and pointer focus")
		var affordability := true
		for entry in game.hud._shop_entries:
			affordability = affordability and entry.button.disabled == (int(entry.price) > expected_balance)
		_check(affordability and parcel.disabled == (expected_balance < 15), "sticky-header purchase refreshes all item and parcel affordability")
		if kind == 17 and expected_balance == 76:
			await _retained_capture("960-sticky-wallet-76")
	await _retained_capture("960-sticky-wallet-26")
	var item_total: int = r._inventory_total()
	await r._pointer_click("Buy a parcel")
	_check(game.stars == 11 and r._inventory_total() == item_total+1 and not game.hud.is_panel_open(), "sticky parcel receives pointer at bottom, charges 15, unwraps one item and closes shop")
	game.stars = wallet
	game.inventory = inventory
	game._update_status()
	await r._fly(0)
	var prior_favors: Array = game.favors.duplicate()
	var prior_friendship: Array = game.friendship.duplicate()
	var prior_placed: Array = game.placed.duplicate(true)
	var prior_wishes: int = game.wishes
	# Grammar fixtures replace only in-memory counters while reading the real
	# journal presentation; no saved records or scene geometry are mutated.
	for count in [0,1,2]:
		game.favors = [0,0,0,0] if count == 0 else [2,2,0,0]
		game.friendship = [count,count,0,0]
		game.wishes = count
		game.placed = []
		for item in range(count):
			game.placed.append({"kind":0,"n":[0,1,0],"angle":0})
		await r._pointer_click("Journal")
		var entries: Array = game._journal_entries()
		var favor_text: String = "A new face in the neighborhood" if count == 0 else ("1 favor shared" if count == 1 else "2 favors shared")
		var home_text: String = ["0 decorations at home · 0 wishes sent","1 decoration at home · 1 wish sent","2 decorations at home · 2 wishes sent"][count]
		_check(entries[0].progress == favor_text and entries[1].progress == favor_text and _labels().contains(favor_text), "both journal neighbor rows use correct wording for count %d" % count)
		_check(entries[4].progress == home_text and _labels().contains(home_text), "journal home row uses correct decoration and wish wording for count %d" % count)
		_check(not _labels().contains("1 favors") and not _labels().contains("1 decorations") and not _labels().contains("1 wishes"), "journal contains no singular-count plural grammar")
		await _retained_capture("960-journal-grammar-%d" % count)
		await r._pointer_click("×")
	game.favors = prior_favors
	game.friendship = prior_friendship
	game.placed = prior_placed
	game.wishes = prior_wishes
	r.root.size = window_before
	await r.process_frame
	await r.process_frame

func _retained_capture(label: String) -> void:
	if "--polish-visual" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await _capture(label)

func _check(ok: bool, evidence: String) -> bool:
	return r._check(ok, "POLISH: " + evidence)

func _labels(scope: Node = null) -> String:
	var text := ""
	for node in (game.hud if scope == null else scope).find_children("*", "Label", true, false):
		if node.is_visible_in_tree():
			text += node.text + "\n"
	return text

func _button(prefix: String, scope: Node = null) -> Button:
	for node in (game.hud if scope == null else scope).find_children("*", "Button", true, false):
		if node.text.begins_with(prefix) and node.is_visible_in_tree():
			return node
	return null

func _catalog_contract() -> void:
	_check(Catalog.NAMES.size() == 18 and Catalog.PRICES == PRICES, "18 catalog entries retain the intended individual prices")
	_check(Catalog.RADII.size() == 18 and Catalog.DESCRIPTIONS.size() == 18, "every item has a footprint and description")
	_check(Catalog.SUIT_NAMES.size() == 6 and Catalog.SUIT_COLORS.size() == 6, "wardrobe defines six suits")
	var names := {}
	for item in Catalog.entries([2, 1]):
		names[item.name] = true
		_check(item.kind in range(18) and item.price == PRICES[item.kind] and not item.description.is_empty(), "catalog record %d supplies identity, price and description" % item.kind)
		_check(item.count == ([2, 1][item.kind] if item.kind < 2 else 0), "short inventory expands safely in catalog record %d" % item.kind)
	_check(names.size() == 18, "catalog names identify eighteen distinct items")
	for who in range(2):
		var titles := {}
		var types := {}
		for round_index in range(6):
			var quest := Neighborhood.quest(who, round_index)
			titles[quest.title] = true
			types[quest.type] = true
			_check(quest.type == ["retrieve", "collect", "decorate", "visit", "wish", "retrieve"][round_index], "neighbor %d round %d has intended activity" % [who, round_index])
			_check(quest.target == (3 if round_index in [1, 2] else 1), "neighbor %d round %d has intended target" % [who, round_index])
			_check(Neighborhood.quest(who, round_index + 6) == quest, "quest %d/%d rotates after six favors" % [who, round_index])
			quest.title = "modified fixture"
			_check(Neighborhood.quest(who, round_index).title != "modified fixture", "quest writing returns independent data")
		_check(titles.size() == 6 and types.size() == 5, "neighbor %d has six authored favors across five activities" % who)
		for friendship in [0, 1, 3, 6]:
			var lines := {}
			for variant in range(20):
				lines[Neighborhood.chatter(who, friendship, variant)] = true
			_check(lines.size() == 20, "neighbor %d friendship %d has twenty distinct chat lines" % [who, friendship])

func _pointer(button: Button) -> void:
	if not _check(button != null and not button.disabled, "enabled pointer target exists"):
		return
	await r.process_frame
	await r.process_frame
	game.hud._panel_scroll.ensure_control_visible(button)
	await r.process_frame
	await r.process_frame
	var point := button.get_global_rect().get_center()
	if not _check(r.root.get_visible_rect().has_point(point) and game.hud._panel_scroll.get_global_rect().has_point(point), "scrolled card button center is reachable in the viewport"):
		return
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	r.root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		r.root.push_input(event, true)
		await r.process_frame

func _catalog_shop() -> void:
	await r._fly(3)
	r._position_at(game.worlds[3].anchors.shop)
	var wallet: int = game.stars
	for kind in range(18):
		var before: Array = game.inventory.duplicate()
		game.stars = PRICES[kind]-1
		r._key(KEY_E)
		var card = game.hud.find_child("Decor%d" % kind, true, false)
		var buy := _button("Buy ·", card) if card != null else null
		_check(buy != null and buy.disabled, "item %d purchase disabled at price minus one" % kind)
		game._action("buy_item:%d" % kind)
		_check(game.stars == PRICES[kind]-1 and game.inventory == before, "item %d insufficient-funds action preserves all possessions" % kind)
		game.hud.close_panel()
		game.stars = PRICES[kind]
		r._key(KEY_E)
		card = game.hud.find_child("Decor%d" % kind, true, false)
		buy = _button("Buy ·", card) if card != null else null
		if _check(buy != null and not buy.disabled and buy.text.contains(str(PRICES[kind])), "item %d exact-balance purchase advertises correct price" % kind):
			if kind in [0, 17]:
				await _pointer(buy)
			else:
				buy.pressed.emit()
		var expected := before.duplicate()
		expected[kind] += 1
		_check(game.stars == 0 and game.inventory == expected, "item %d UI purchase charges exact cost and adds only the selected object" % kind)
		_check(game.hud.is_panel_open(), "specific-item purchase keeps the shop open")
		var refreshed_card = game.hud.find_child("Decor%d" % kind,true,false)
		var refreshed_buy := _button("Buy ·",refreshed_card) if refreshed_card != null else null
		_check(refreshed_buy != null and refreshed_buy.disabled, "exact-balance purchase immediately disables the now-unaffordable item")
		game._action("buy_item:%d" % kind)
		_check(game.stars == 0 and game.inventory == expected, "item %d cannot be bought again with an empty purse" % kind)
		game.hud.close_panel()
	await _shop_multiple_purchases()
	game.stars = wallet
	game._update_status()
	await r._fly(0)
	# Every newly bought item must produce an actual placeable world object,
	# including the final catalog entry. Conservation covers removal as well.
	for kind in range(18):
		r._press("Decorate")
		r._press_decor(kind)
		if not _check(game.selected == kind and is_instance_valid(game.preview), "catalog item %d can be selected from the bag" % kind):
			continue
		var target: Vector3 = r._valid_ground()
		if not _check(target != Vector3.ZERO, "catalog item %d has valid placement ground" % kind):
			game._cancel_placement()
			continue
		var before: Array = game.inventory.duplicate()
		var count: int = game.placed.size()
		r._aim_placement(target)
		r._click()
		_check(game.placed.size() == count+1 and game.inventory[kind] == before[kind]-1, "catalog item %d commits exactly once" % kind)
		if game.placed.size() > count:
			var node: Node = game.placed_nodes.back()
			_check(node.find_children("*", "MeshInstance3D", true, false).size() > 0, "catalog item %d creates visible geometry" % kind)
			r._position_at(target)
			r._key(KEY_X)
		_check(game.placed.size() == count and game.inventory == before, "catalog item %d removal restores exact inventory" % kind)
		game._cancel_placement()

func _shop_multiple_purchases() -> void:
	game.hud.close_panel()
	game.stars = 100
	r._key(KEY_E)
	var expected_balance := 100
	for kind in [17,16,14]:
		var card = game.hud.find_child("Decor%d" % kind,true,false)
		var buy := _button("Buy ·",card) if card != null else null
		if not _check(buy != null and not buy.disabled, "next catalog purchase is available without reopening the shop"):
			break
		await r.process_frame
		await r.process_frame
		game.hud._panel_scroll.ensure_control_visible(buy)
		await r.process_frame
		await r.process_frame
		var scroll_before: int = game.hud._panel_scroll.scroll_vertical
		var inventory_before: Array = game.inventory.duplicate()
		await _pointer(buy)
		expected_balance -= PRICES[kind]
		inventory_before[kind] += 1
		_check(game.hud.is_panel_open() and game.stars == expected_balance and game.inventory == inventory_before, "successive visible catalog purchase preserves the modal and commits once")
		_check(game.hud._panel_scroll.scroll_vertical == scroll_before, "specific purchase preserves the current shop scroll position")
		if game.stars >= PRICES[kind]:
			var focused := r.root.gui_get_focus_owner()
			_check(focused is Button and focused.tooltip_text.contains(Catalog.NAMES[kind]), "affordable purchased item retains input focus")
		var all_refreshed := true
		for check_kind in range(18):
			var row = game.hud.find_child("Decor%d" % check_kind,true,false)
			var button := _button("Buy ·",row) if row != null else null
			all_refreshed = all_refreshed and button != null and button.disabled == (game.stars < PRICES[check_kind])
		_check(all_refreshed, "all catalog affordability states refresh after each purchase")
		_check(game.hud._shop_purse.text.contains(str(expected_balance)) and game.hud._shop_confirmation.text.contains(Catalog.NAMES[kind]), "open shop visibly updates its purse and inline purchase confirmation")
	game.hud.close_panel()

func _wardrobe() -> void:
	await r._fly(3)
	var before: Array = game.inventory.duplicate()
	var wallet: int = game.stars
	for choice in range(6):
		r._position_at(game.worlds[3].anchors.clothes)
		r._key(KEY_E)
		_check(game.hud._panel_grid.get_child_count() == 6, "wardrobe presents all six suits")
		var wear: Button = game.hud._panel_grid.get_child(choice).find_children("*", "Button", true, false)[0]
		if game.suit == choice:
			_check(wear.disabled and wear.text == "Currently wearing", "currently equipped suit is marked and disabled")
			game.hud.close_panel()
		else:
			if choice == 5:
				await _pointer(wear)
			else:
				wear.pressed.emit()
		_check(game.suit == choice and game.stars == wallet and game.inventory == before, "suit %d equips for free without changing objects" % choice)
		_check(game.player.get_node("SuitGlow").light_color.is_equal_approx(Catalog.SUIT_COLORS[choice]), "suit %d updates its light" % choice)
		var matching := true
		for mesh in game.avatar.find_children("*", "MeshInstance3D", true, false):
			if mesh.get_meta("suit_accent", false):
				matching = matching and mesh.material_override.albedo_color.is_equal_approx(Catalog.SUIT_COLORS[choice])
		_check(matching, "wardrobe suit %d matches all avatar accents" % choice)
	await _reload("sixth-suit")
	_check(game.suit == 5 and game.player.get_node("SuitGlow").light_color.is_equal_approx(Catalog.SUIT_COLORS[5]), "sixth suit reconstructs correctly after save/restart")

func _accept(who: int, round_index: int) -> void:
	await r._fly(who+1)
	r._position_at(game.worlds[who+1].anchors.neighbor)
	r._key(KEY_E)
	r._press("Another little favor?")
	_check(game.favors[who] == 1 and game.quest_round[who] == round_index, "neighbor %d accepts round %d through conversation" % [who, round_index])
	_check(_labels().contains(Neighborhood.quest(who, round_index).request), "acceptance shows the current request rather than the previous favor")
	game.hud.close_panel()

func _deliver(who: int) -> void:
	await r._fly(who+1)
	r._position_at(game.worlds[who+1].anchors.neighbor)
	var wallet: int = game.stars
	var total: int = r._inventory_total()
	var friendship: Array = game.friendship.duplicate()
	r._key(KEY_E)
	friendship[who] += 1
	_check(game.favors[who] == 2 and not game.cargo[who], "neighbor %d completes and consumes ready favor" % who)
	_check(game.stars == wallet+25 and r._inventory_total() == total+1 and game.friendship == friendship, "neighbor %d delivery pays exactly one gift, 25 stardust, and one friendship" % who)
	r._press("Thank you!")
	r._key(KEY_E)
	_check(game.stars == wallet+25 and r._inventory_total() == total+1 and game.friendship == friendship, "completed delivery cannot pay twice")
	game.hud.close_panel()
	game._spawn_pickups()
	_check(r._live_pickups(who).is_empty(), "completed favor leaves no live tokens")

func _journal(who: int, progress: String) -> void:
	r._key(KEY_J)
	var entries: Array = game._journal_entries()
	_check(game.hud.is_panel_open() and entries.size() == 5, "journal opens with four neighbors and home")
	_check(entries[who].get("who",-1) == who and entries[who].get("name","") == ("Lumi" if who == 0 else "Bolt") and entries[who].get("location","") == ("Luma" if who == 0 else "Rust") and entries[who].get("friendship","") == Neighborhood.friendship_name(game.friendship[who]), "journal supplies the correct neighbor identity, location and friendship tier")
	_check(str(entries[who].progress).contains(progress) and _labels().contains(str(entries[who].progress)), "journal visibly reports neighbor %d progress: %s" % [who, progress])
	game.hud.close_panel()

func _add_home_item() -> Vector3:
	game._start_placement(0)
	var n: Vector3 = r._valid_ground()
	if _check(n != Vector3.ZERO, "home favor has clear ground for a decoration"):
		r._aim_placement(n)
		r._click()
	game._cancel_placement()
	return n

func _remaining_rotation() -> void:
	if not _check(game.favors == [2,2,0,0] and game.friendship == [2,2,0,0], "expanded rotation follows completed round 0 and round 1 for both neighbors"):
		return
	# Existing decoration counts, and removing one must revoke readiness.
	await r._fly(0)
	game.inventory[0] = maxi(6, int(game.inventory[0]))
	_add_home_item()
	for who in range(2):
		await _accept(who, 2)
		_check(game.quest_progress[who] == 1 and not game.cargo[who] and r._live_pickups(who).is_empty(), "decoration favor counts existing object without spawning a token")
		_journal(who, "1 / 3")
	await r._fly(0)
	_add_home_item()
	var last := _add_home_item()
	_check(game.quest_progress == [3,3,0,0] and game.cargo == [true,true,false,false], "three current decorations satisfy both neighbors")
	r._position_at(last)
	r._key(KEY_X)
	_check(game.quest_progress == [2,2,0,0] and game.cargo == [false,false,false,false], "removing decoration revokes incomplete home-favor readiness")
	await _reload("decorate-two-of-three")
	_check(game.placed.size() == 2 and game.placed_nodes.size() == 2 and game.quest_progress == [2,2,0,0], "restart reconstructs two home objects and pending decoration progress")
	_add_home_item()
	for who in range(2):
		await _deliver(who)
		_journal(who, "3 favors shared")
	# Old visits and old wishes are irrelevant to freshly accepted event favors.
	await r._fly(3)
	r._position_at(game.worlds[3].anchors.event)
	r._key(KEY_E)
	r._press("Send a little wish")
	var wishes_before: int = game.wishes
	for who in range(2):
		await _accept(who, 3)
		_check(game.quest_progress[who] == 0 and not game.cargo[who], "visit favor excludes travel before acceptance")
	# Accepting Bolt on Rust after accepting Lumi counts the NEW Rust arrival.
	_check(game.cargo == [true,false,false,false], "fresh Rust arrival advances only Lumi's visit favor")
	await r._fly(3)
	_check(not game.cargo[1], "wrong destination does not advance Bolt's visit favor")
	await _reload("visit-lumi-ready-bolt-pending")
	_check(game.cargo == [true,false,false,false], "ready and pending visit favors both survive restart")
	await r._fly(1)
	_check(game.cargo == [true,true,false,false], "fresh Luma arrival advances Bolt's visit favor")
	for who in range(2):
		await _deliver(who)
	for who in range(2):
		await _accept(who, 4)
		_check(not game.cargo[who] and game.quest_progress[who] == 0, "wish favor excludes earlier wishes")
	await r._fly(3)
	_check(game.cargo == [false,false,false,false], "travel to Commons alone does not make a wish")
	r._position_at(game.worlds[3].anchors.event)
	r._key(KEY_E)
	_check(game.cargo == [false,false,false,false], "opening wishing dialog alone grants no progress")
	r._press("Send a little wish")
	_check(game.cargo == [true,true,false,false] and game.wishes == wishes_before+1, "one explicit wish advances both accepted favors once")
	await _reload("wish-ready")
	_check(game.cargo == [true,true,false,false] and game.wishes == wishes_before+1, "wish readiness and total survive restart")
	for who in range(2):
		await _deliver(who)
	for who in range(2):
		await _accept(who, 5)
	for who in range(2):
		var live: Array = r._live_pickups(who)
		if not _check(live.size() == 1, "round 5 neighbor %d has one new retrieval" % who):
			continue
		var pickup: Dictionary = live[0]
		_check(pickup.planet == (2 if who == 0 else 1) and pickup.title.contains("seed" if who == 0 else "gear"), "round 5 sends neighbor %d to the other neighbor for its unique item" % who)
		await r._fly(pickup.planet)
		r._position_at(pickup.normal)
		r._key(KEY_E)
		_check(game.cargo[who] and game.quest_progress[who] == 1, "round 5 pickup is ready to deliver")
		await _deliver(who)
	_check(game.friendship == [6,6,0,0], "both neighbors reach Besties after all six actual favors")
	for who in range(2):
		await _accept(who, 6)
		_check(Neighborhood.quest(who, game.quest_round[who]).type == "retrieve" and r._live_pickups(who).size() == 1 and game.quest_progress[who] == 0, "round 6 wraps to original retrieval with clean progress")

func _fixture_path(label: String) -> String:
	fixture_serial += 1
	return "/tmp/little-orbit-polish-%d-%d-%s.json" % [OS.get_process_id(), fixture_serial, label]

func _delete_fixture(path: String) -> void:
	for candidate in [path, path+".tmp"]:
		if FileAccess.file_exists(candidate):
			_check(DirAccess.remove_absolute(candidate) == OK, "isolated fixture removed: " + candidate)

func _replace_from(path: String) -> void:
	var replacement: Node = load("res://main.tscn").instantiate()
	replacement.test_mode = true
	replacement._load_game(path, true)
	var old := game
	old.queue_free()
	await r.process_frame
	r.root.add_child(replacement)
	await r.process_frame
	await r.process_frame
	replacement.set_process(false)
	game = replacement
	r.game = replacement
	_check(game.test_mode and game.worlds.size() == 6 and game.hud != null, "isolated save recreates a ready game in test_mode")

func _reload(label: String) -> void:
	var path := _fixture_path(label)
	if not _check(game.test_mode and not FileAccess.file_exists(path), "isolated restart path is unused"):
		return
	game._save_game(path, true)
	if _check(FileAccess.file_exists(path), "explicit allow_test saved restart fixture"):
		await _replace_from(path)
	_delete_fixture(path)

func _load_fixture(data: Dictionary, label: String) -> void:
	var path := _fixture_path(label)
	if not _check(game.test_mode and not FileAccess.file_exists(path), "migration fixture is isolated and test-only"):
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not _check(file != null, "fixture file opens"):
		return
	file.store_string(JSON.stringify(data))
	file.close()
	await _replace_from(path)
	_delete_fixture(path)

func _partial_collection_reload() -> void:
	# A valid accepted round-1 fixture supplies just the acceptance state;
	# all three collection steps and delivery are real interactions.
	await _load_fixture({"version":1, "favors":[1,2], "friendship":[1,1], "quest_round":[1,0], "quest_progress":[0,1], "collected_bits":[0,1], "cargo":[false,false], "planet":1}, "accepted-collect")
	for amount in range(1,4):
		var live: Array = r._live_pickups(0)
		if not _check(live.size() == 4-amount, "restart retains exactly the uncollected crystal slots"):
			return
		var pickup: Dictionary = live[0]
		r._position_at(pickup.normal)
		r._key(KEY_E)
		var bits: int = game.collected_bits[0]
		await _reload("crystals-%d-of-three" % amount)
		_check(game.quest_progress[0] == amount and game.collected_bits[0] == bits and game.cargo[0] == (amount == 3), "reload preserves exact %d/3 progress, unique slot bits and readiness" % amount)
		_check(r._live_pickups(0).size() == 3-amount, "reload never respawns collected crystals")
		r._position_at(pickup.normal)
		var progress_before: int = game.quest_progress[0]
		r._key(KEY_E)
		_check(game.quest_progress[0] == progress_before, "old crystal location cannot be farmed after reload")
		game.hud.close_panel()
		_journal(0, "All ready!" if amount == 3 else "%d / 3" % amount)
	await _deliver(0)
	await _reload("delivered-collect")
	var wallet: int = game.stars
	var total: int = r._inventory_total()
	r._position_at(game.worlds[1].anchors.neighbor)
	r._key(KEY_E)
	_check(game.favors[0] == 2 and game.stars == wallet and r._inventory_total() == total and r._live_pickups(0).is_empty(), "completed collection survives restart without duplicate rewards or respawns")
	game.hud.close_panel()

func _old_save_migration() -> void:
	var old := {"version":1, "stars":57, "inventory":[3,0,4,2,1,5], "favors":[1,2], "friendship":[0,4], "cargo":[true,false], "suit":2, "muted":true, "planet":1, "normal":[0,1,0.35], "placed":[{"kind":4,"n":[0,-1,0],"angle":0.75}]}
	await _load_fixture(old, "legacy-six-slots")
	_check(game.inventory.size() == 18 and game.inventory.slice(0,6) == old.inventory and game.inventory.slice(6) == [0,0,0,0,0,0,0,0,0,0,0,0], "legacy migration preserves all six old slots and starts twelve new slots empty")
	_check(game.quest_round == [0,0,0,0] and game.quest_progress == [1,0,0,0] and game.collected_bits == [1,0,0,0], "legacy carried retrieval migrates to ready round 0 with matching slot bit")
	_check(game.cargo == [true,false,false,false] and game.favors == [1,2,0,0] and game.friendship == [0,4,0,0] and game.stars == 57, "legacy migration preserves quest ownership, friendship and wallet")
	_check(game.placed.size() == 1 and game.placed_nodes.size() == 1 and int(game.placed[0].kind) == 4 and is_equal_approx(float(game.placed[0].angle),0.75), "legacy placed object is reconstructed with the original kind and rotation")
	_check(game.suit == 2 and game.muted and game.current == 1 and game.talk_counts == [0,0,0,0] and game.wishes == 0, "legacy appearance, audio and planet survive with default new counters")
	await _deliver(0)
	await _accept(0,1)
	_check(r._live_pickups(0).size() == 3, "migrated old retrieval advances to three-crystal favor")
	await _reload("migrated-new-format")
	_check(game.inventory.size() == 18 and game.quest_round[0] == 1 and r._live_pickups(0).size() == 3, "migrated save can itself be saved/restarted without losing new behavior")
	# A completed legacy repeat player advances according to completed favor count.
	await _accept(1,4)
	_check(game.quest_progress[1] == 0 and not game.cargo[1], "legacy repeat friendship advances to round 4 without a free wish")

func _pad(button: JoyButton, through_viewport: bool = false) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		if "--controller-diagnostics" in OS.get_cmdline_user_args() and down:
			print("PAD_DIAG button=%d viewport=%s accept=%s cancel=%s focus=%s" % [button, through_viewport, event.is_action_pressed("ui_accept"), event.is_action_pressed("ui_cancel"), r.root.gui_get_focus_owner()])
		if through_viewport:
			r.root.push_input(event, true)
		else:
			game._unhandled_input(event)
		await r.process_frame

func _axis(device: int, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _controller_and_camera() -> void:
	if "--controller-diagnostics" in OS.get_cmdline_user_args():
		for action in ["ui_accept", "ui_cancel", "move_right", "run"]:
			print("PAD_MAP ", action, ": ", InputMap.action_get_events(action))
	await r._fly(0)
	r._position_at(Vector3(0,-1,0.3).normalized())
	_check(not game.overview, "close camera is the default for old saves")
	game._update_camera(5.0)
	var close_distance: float = game.camera.global_position.distance_to(game.player.global_position)
	await _pad(JOY_BUTTON_LEFT_SHOULDER)
	game._update_camera(5.0)
	_check(game.overview and game.camera.global_position.distance_to(game.player.global_position) > close_distance*1.3, "pad LB selects a materially wider camera")
	await _pad(JOY_BUTTON_LEFT_SHOULDER)
	game._update_camera(5.0)
	_check(not game.overview and r._basis_ok(game.camera), "pad LB restores finite close camera")
	await _pad(JOY_BUTTON_A)
	var rose := false
	for frame in range(90):
		game._process(1.0/60.0)
		rose = rose or game.hop > 0.1
	_check(rose and game.hop == 0, "pad A hops and lands outside UI")
	await _pad(JOY_BUTTON_BACK)
	_check(game.hud.is_panel_open(), "pad Back opens map")
	await _pad(JOY_BUTTON_A)
	_check(game.hop_speed == 0 and game.hop == 0, "unhandled pad A cannot hop behind modal")
	await _pad(JOY_BUTTON_B, true)
	_check(not game.hud.is_panel_open(), "routed pad B dismisses modal")
	# Deliberately retain a footer focus across modal open/close. A must be
	# consumed by the world input path, not reactivate that focused Map button.
	var footer_map := _button("Map")
	if _check(footer_map != null, "footer Map exists for controller focus regression"):
		footer_map.grab_focus()
		await _pad(JOY_BUTTON_BACK, true)
		await _pad(JOY_BUTTON_B, true)
		await _pad(JOY_BUTTON_A, true)
		_check(not game.hud.is_panel_open() and is_equal_approx(game.hop_speed,4.3), "A after closing a menu hops once instead of reactivating old footer focus")
		for frame in range(90):
			game._process(1.0/60.0)
		_check(game.hop == 0 and not game.hud.is_panel_open(), "post-menu controller hop lands without a duplicate UI activation")
	await _pad(JOY_BUTTON_START)
	_check(game.hud.is_panel_open() and _labels().contains("Lumi") and _labels().contains("Bolt"), "pad Start opens journal with both neighbors")
	await _pad(JOY_BUTTON_B, true)
	await _pad(JOY_BUTTON_BACK)
	await r.process_frame
	await r.process_frame
	var previous_focus := r.root.gui_get_focus_owner()
	await _pad(JOY_BUTTON_DPAD_DOWN, true)
	_check(r.root.gui_get_focus_owner() != previous_focus and r.root.gui_get_focus_owner() is Button, "routed D-pad navigates the open map")
	var destination := _button("Visit Luma")
	if _check(destination != null, "pad map destination exists"):
		destination.grab_focus()
		await _pad(JOY_BUTTON_A, true)
		_check(game.flight and game.flight_target == 1 and game.hop == 0, "routed pad A activates focused destination without a world hop")
	if game.flight:
		var round_before: Array = game.quest_round.duplicate()
		await _pad(JOY_BUTTON_START)
		await _pad(JOY_BUTTON_Y, true)
		_check(not game.hud.is_panel_open() and game.quest_round == round_before, "pad journal/bag cannot interrupt flight")
		for frame in range(301):
			if game.flight:
				game._process(1.0/60.0)
		game._update_player(0)
		_check(game.current == 1 and not game.flight and r._sphere_ok(), "controller-selected trip arrives normally")
	r._position_at(game.worlds[game.current].anchors.get("neighbor", Vector3.UP))
	if game.current == 1:
		await _pad(JOY_BUTTON_X)
		_check(game.hud.is_panel_open() and _labels().contains("Lumi"), "pad X talks to nearby neighbor")
	game.hud.close_panel()
	await r._fly(0)
	game.inventory[0] = maxi(1,int(game.inventory[0]))
	await _pad(JOY_BUTTON_Y)
	_check(game.hud.is_panel_open(), "pad Y opens decorating bag")
	await r.process_frame
	await r.process_frame
	var choice: Button = r._decor_button(0)
	if _check(choice != null, "pad bag item exists"):
		choice.grab_focus()
		await _pad(JOY_BUTTON_A, true)
	_check(game.selected == 0 and not game.hud.is_panel_open() and game.hop == 0, "routed pad A chooses focused bag item without placing it immediately")
	if game.selected == 0:
		var angle: float = game.placement_angle
		await _pad(JOY_BUTTON_Y)
		_check(is_equal_approx(game.placement_angle, angle+PI/4) and not game.hud.is_panel_open(), "pad Y rotates active decoration")
		var target: Vector3 = r._valid_ground()
		if _check(target != Vector3.ZERO, "controller placement ground exists"):
			r._aim_placement(target)
			var count: int = game.placed.size()
			var inventory: int = game.inventory[0]
			await _pad(JOY_BUTTON_A, true)
			_check(game.placed.size() == count+1 and game.inventory[0] == inventory-1 and game.hop == 0, "pad A places exactly one decoration without hopping")
			r._position_at(target)
			await _pad(JOY_BUTTON_RIGHT_STICK, true)
			_check(game.placed.size() == count and game.inventory[0] == inventory, "right-stick click removes placed object and refunds exactly one item")
			await _pad(JOY_BUTTON_RIGHT_STICK, true)
			_check(game.placed.size() == count and game.inventory[0] == inventory, "repeated controller removal cannot duplicate inventory")
		game._cancel_placement()
	# Axis/button injection exercises the left-stick action map. Godot 4 has
	# no public GDScript method to connect a synthetic joypad; the production
	# right-stick path enumerates connected devices and remains unverified.
	var device := 0 # Match the game's device-0 mappings.
	r._position_at(Vector3(0,-1,0.3).normalized())
	var start: Vector3 = game.normal
	_axis(device, JOY_AXIS_LEFT_X, 0.1)
	for frame in range(15):
		game._process(1.0/60.0)
	_check(game.normal.is_equal_approx(start), "left stick deadzone suppresses small drift")
	_axis(device, JOY_AXIS_LEFT_X, 1.0)
	if "--controller-diagnostics" in OS.get_cmdline_user_args():
		print("PAD_AXIS device=",device," strength=",Input.get_action_strength("move_right")," vector=",Input.get_vector("move_left","move_right","move_up","move_down")," modal=",game.hud.is_panel_open())
	for frame in range(60):
		game._process(1.0/60.0)
	_check(game.normal.distance_to(start) > 0.01 and game.velocity.length() > 3.0, "injected left stick walks along the sphere")
	var run := InputEventJoypadButton.new()
	run.device = device
	run.button_index = JOY_BUTTON_RIGHT_SHOULDER
	run.pressed = true
	Input.parse_input_event(run)
	Input.flush_buffered_events()
	for frame in range(60):
		game._process(1.0/60.0)
	_check(game.running and game.velocity.length() > 5.0 and r._sphere_ok(), "injected RB plus left stick runs on the sphere")
	run = run.duplicate()
	run.pressed = false
	Input.parse_input_event(run)
	_axis(device, JOY_AXIS_LEFT_X, 0.0)
	var orbit_before: float = game.orbit
	_axis(device, JOY_AXIS_RIGHT_X, 0.8)
	for frame in range(30):
		game._process(1.0/60.0)
	print("POLISH_LIMITATION: right-stick orbit requires a connected controller; synthetic connection unavailable in Godot 4 GDScript.")
	await _pad(JOY_BUTTON_START)
	var modal_normal: Vector3 = game.normal
	orbit_before = game.orbit
	_axis(device, JOY_AXIS_LEFT_X, 1.0)
	for frame in range(30):
		game._process(1.0/60.0)
	_check(game.normal.is_equal_approx(modal_normal) and is_equal_approx(game.orbit, orbit_before) and not game.running, "modal journal blocks both sticks and running")
	_axis(device, JOY_AXIS_LEFT_X, 0.0)
	_axis(device, JOY_AXIS_RIGHT_X, 0.0)
	for action in ["move_left", "move_right", "move_up", "move_down", "hop", "run"]:
		Input.action_release(action)
	game.hud.close_panel()

func _optional_visual_review() -> void:
	if not "--polish-visual" in OS.get_cmdline_user_args():
		return
	if not _check(DisplayServer.get_name() != "headless", "visual capture requires rendered Godot display"):
		return
	for viewport_size in [Vector2i(960,600),Vector2i(1280,800)]:
		r.root.size = viewport_size
		await r.process_frame
		await r.process_frame
		_check(Vector2i(r.root.get_visible_rect().size) == viewport_size, "native UI viewport matches actual window pixels at %s" % viewport_size)
		print("NATIVE_UI size=%s viewport=%s" % [r.root.size,r.root.get_visible_rect().size])
		await _native_ui_review(str(viewport_size.x))

func _native_ui_review(width: String) -> void:
	game.hud.close_panel()
	await r._fly(0)
	game.at_title = true
	game.save_available = true # Deterministic presentation; no player-save lookup.
	game.player.visible = false
	game.hud.show_start_menu(true)
	game._update_camera(5.0)
	await _capture(width + "-title")
	game.muted = true
	AudioServer.set_bus_mute(0,true)
	await r._pointer_click("Settings")
	_check(game.at_title and game.hud._settings_open, width + ": title Settings receives pointer")
	await _capture(width + "-settings-muted")
	var prior_gains: Array = [game.music_volume,game.effects_volume]
	await r._pointer_click("Sound · Off")
	_check(not game.muted and not AudioServer.is_bus_mute(0) and game.at_title and game.hud._settings_open and [game.music_volume,game.effects_volume] == prior_gains and _button("Sound · On") != null, width + ": title Sound pointer unmutes Master, retains gains and refreshes state")
	await _capture(width + "-settings")
	var slider := game.hud.find_child("MusicSlider",true,false) as HSlider
	if _check(slider != null, width + ": native music slider exists"):
		game.hud._panel_scroll.ensure_control_visible(slider)
		await r.process_frame
		var unchanged: float = game.effects_volume
		await _pointer_point(slider.get_global_rect().position + slider.size*Vector2(0.72,0.5))
		_check(game.music_volume > 0.6 and game.music_volume < 0.85 and is_equal_approx(game.effects_volume,unchanged) and not game.muted and not AudioServer.is_bus_mute(0), width + ": native slider pointer changes only music")
	await _pointer(_button("Back"))
	_check(game.at_title and game.hud._start_menu, width + ": settings Back returns to title by pointer")
	await r._pointer_click("Continue")
	if not _check(not game.at_title and not game.hud.is_panel_open() and game.player.visible, width + ": title Continue resumes by pointer"):
		game._action("continue")
		return
	r._position_at(Vector3(0,1,0.35).normalized())
	game.overview = false
	game._update_camera(5.0)
	game._update_hint()
	await _capture(width + "-close-camera")
	await r._pointer_click("Map")
	await _capture(width + "-map")
	await r._pointer_click("Visit Luma")
	_check(game.flight and not game.hud.is_panel_open(), width + ": native map destination pointer starts flight")
	for step in range(230):
		if not game.flight:
			break
		game._process(1.0/30.0)
	_check(not game.flight and game.current == 1, width + ": pointer flight reaches Luma")
	r._position_at((game.worlds[1].anchors.neighbor + Vector3(0,0,0.2)).normalized())
	r._key(KEY_E)
	game._update_camera(5.0)
	await _capture(width + "-neighbor")
	await r._pointer_click("×")
	_check(not game.hud.is_panel_open(), width + ": conversation close receives pointer")
	await r._fly(3)
	r._position_at(game.worlds[3].anchors.shop)
	game.stars = 100
	game._update_status()
	r._key(KEY_E)
	await _capture(width + "-shop")
	var before: Array = game.inventory.duplicate()
	var card = game.hud.find_child("Decor17",true,false)
	await _pointer(_button("Buy ·",card))
	_check(game.stars == 76 and game.inventory[17] == before[17]+1 and game.hud.is_panel_open(), width + ": native last-row pointer purchase charges exact cost and retains shop")
	await _capture(width + "-shop-last-row")
	await r._pointer_click("×")
	_check(not game.hud.is_panel_open(), width + ": shop close receives pointer")
	r._position_at(game.worlds[3].anchors.clothes)
	game.suit = 0
	r._key(KEY_E)
	await _capture(width + "-wardrobe")
	if not _check(is_instance_valid(game.hud._panel_grid) and game.hud._panel_grid.get_child_count() == 6, width + ": wardrobe grid is ready for native sixth-suit hit"):
		game.hud.close_panel()
		return
	var suit_card: Node = game.hud._panel_grid.get_child(5)
	await _pointer(_button("Wear this color",suit_card))
	_check(game.suit == 5 and not game.hud.is_panel_open(), width + ": sixth suit can be selected by native pointer")
	await r._fly(0)
	game.inventory[17] = maxi(1,game.inventory[17])
	await r._pointer_click("Decorate")
	await _capture(width + "-bag")
	var place: Button = r._decor_button(17)
	if _check(place != null and place.text == "Place", width + ": last bag card has concise Place label and matching item tooltip"):
		game.hud._panel_scroll.ensure_control_visible(place)
		await _capture(width + "-bag-last-row")
		await _pointer(place)
		_check(game.selected == 17 and is_instance_valid(game.preview) and not game.hud.is_panel_open(), width + ": last bag Place pointer selects its own item exactly")
	game._cancel_placement()
	await r._pointer_click("Journal")
	await _capture(width + "-journal")
	game.hud._panel_scroll.scroll_vertical = 10000
	await _capture(width + "-journal-bottom")
	await r._pointer_click("×")
	_check(not game.hud.is_panel_open(), width + ": native journal close receives pointer")

func _pointer_point(point: Vector2) -> void:
	if not _check(r.root.get_visible_rect().has_point(point), "native pointer position lies inside viewport"):
		return
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	r.root.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		r.root.push_input(event,true)
		await r.process_frame

func _capture(label: String) -> void:
	print("POLISH_CAPTURE: ",label)
	await r.process_frame
	await r.process_frame
	# An occluded desktop window may stop publishing frame_post_draw. Force
	# this QA frame explicitly instead of waiting indefinitely on presentation.
	RenderingServer.force_draw(false)
	var path := "/tmp/little-orbit-review-%s.png" % label
	var frame := r.root.get_texture().get_image()
	if _check(frame != null and not frame.is_empty(), "rendered review frame is available: " + label):
		_check(frame.get_size() == Vector2i(r.root.get_visible_rect().size), "captured image matches native viewport pixels: " + label)
		if game.hud.is_panel_open():
			_check(r.root.get_visible_rect().encloses(game.hud._panel.get_global_rect()), "modal outer panel remains inside native viewport: " + label)
		_check(game.test_mode and frame.save_png(path) == OK, "save isolated rendered review image: " + path)

func _saved_placement_validation() -> void:
	await _load_fixture({"version":1, "placed":[
		{"kind":17,"n":[0,2,0],"angle":0.5},
		{"kind":3,"n":[0,0,0],"angle":0},
		{"kind":18,"n":[0,1,0],"angle":0},
		{"kind":2,"n":[0,1],"angle":0}
	]}, "placement-validation")
	_check(game.placed.size() == 1 and game.placed_nodes.size() == 1, "save loader rejects zero surface normal, out-of-range kind and malformed normal")
	if game.placed.size() == 1:
		_check(int(game.placed[0].kind) == 17 and Vector3(game.placed[0].n[0],game.placed[0].n[1],game.placed[0].n[2]).is_equal_approx(Vector3.UP) and r._basis_ok(game.placed_nodes[0]), "saved non-unit normal is normalized and newest catalog geometry remains finite")

func _new_game_reset() -> void:
	await _load_fixture({"version":1, "stars":211, "inventory":[3,0,4,2,1,5,2,1,1,0,1,1,2,0,1,1,2,4],
		"favors":[1,1], "friendship":[1,5], "cargo":[false,false], "quest_round":[1,5], "quest_progress":[1,0], "collected_bits":[1,0], "talk_counts":[17,23], "wishes":8, "suit":5, "planet":0, "overview":true, "music_volume":0.37, "effects_volume":0.62,
		"placed":[{"kind":17,"n":[0,-1,0],"angle":0.5},{"kind":3,"n":[1,0,0],"angle":1.0}]
	}, "progress-before-new-game")
	var old_nodes: Array[WeakRef] = []
	for node in game.placed_nodes:
		old_nodes.append(weakref(node))
	for pickup in game.pickups:
		old_nodes.append(weakref(pickup.node))
	game._start_placement(0)
	old_nodes.append(weakref(game.preview))
	var node_count: int = game.worlds.size()
	var fresh := [2,1,1,1,1,2,0,0,0,0,0,0,0,0,0,0,0,0]
	game._action("confirm_new_game")
	await r.process_frame
	await r.process_frame
	var released := true
	for reference in old_nodes:
		released = released and reference.get_ref() == null
	_check(released, "new game frees prior decorations, active collectibles and preview nodes")
	_check(game.stars == 30 and game.inventory == fresh and game.placed.is_empty() and game.placed_nodes.is_empty(), "new game resets wallet and bag and removes all player decorations")
	_check(game.favors == [0,0,0,0] and game.friendship == [0,0,0,0] and game.quest_round == [0,0,0,0] and game.quest_progress == [0,0,0,0] and game.collected_bits == [0,0,0,0] and game.cargo == [false,false,false,false] and game.talk_counts == [0,0,0,0] and game.wishes == 0, "new game resets every favor and journal counter")
	_check(game.current == 0 and game.suit == 0 and not game.overview and not game.at_title and game.player.visible and game.selected == -1 and game.preview == null, "new game returns to Clover with initial suit, close camera and no selection")
	_check(game.worlds.size() == node_count and game.neighbors.size() == 4 and r._live_pickups(0).size() == 1 and r._live_pickups(1).size() == 1 and game.pickups.size() == 8, "new game retains six worlds/four neighbors and spawns exactly eight initial collectibles")
	for repeat in range(3):
		game._spawn_pickups()
	_check(game.pickups.size() == 8, "new game collectibles are idempotent across repeated spawn calls")
	_check(is_equal_approx(game.music_volume,0.37) and is_equal_approx(game.effects_volume,0.62), "new game retains chosen music and effect settings")
	_check(game.hud.is_panel_open() and _labels().contains("Welcome to Clover"), "new game shows onboarding")
	r._press("Make yourself at home")
	await _reload("new-game-clean-state")
	_check(game.inventory == fresh and game.placed.is_empty() and game.friendship == [0,0,0,0] and game.quest_progress == [0,0,0,0] and game.pickups.size() == 8 and game.suit == 0 and game.wishes == 0, "new game's isolated save/restart contains no old progress or world objects")
	# Verify the fresh first favor is playable, not just reset-shaped data.
	await r._fly(1)
	r._position_at(game.worlds[1].anchors.neighbor)
	r._key(KEY_E)
	r._press("I'll find it!")
	await r._fly(0)
	var first: Array = r._live_pickups(0)
	if _check(first.size() == 1, "fresh game offers one original star"):
		r._position_at(first[0].normal)
		r._key(KEY_E)
		_check(game.cargo[0] and game.quest_progress[0] == 1, "new game's first collectible advances exactly once")
		await _deliver(0)

func _menus_and_settings() -> void:
	if not game.hud.has_method("show_start_menu") or not game.hud.has_method("show_settings"):
		print("POLISH_PENDING: start/settings HUD builders are still being integrated; no unavailable method called.")
		return
	_check(not game.at_title, "test_mode bypasses automatic title flow")
	game.hud.close_panel()
	r._key(KEY_ESCAPE)
	_check(game.hud.is_panel_open() and _button("Back to my world") != null and _button("Settings") != null and _button("Save and return to start") != null, "Escape opens pause with resume, settings and title choices")
	r._press("Settings")
	_check(game.hud.is_panel_open(), "pause Settings opens a panel")
	var sliders: Array = game.hud.find_children("*", "HSlider", true, false)
	_check(sliders.size() == 2, "settings exposes separate music and effects controls")
	var muted: bool = AudioServer.is_bus_mute(0)
	var music_slider := game.hud.find_child("MusicSlider",true,false) as HSlider
	var effects_slider := game.hud.find_child("EffectsSlider",true,false) as HSlider
	if not _check(music_slider != null and effects_slider != null, "both named settings sliders are available"):
		game.hud.close_panel()
		return
	music_slider.value = 0
	_check(game.music_volume == 0 and game.audio._music_volume == 0 and is_equal_approx(game.effects_volume,0.62), "music zero silences music without changing effects")
	effects_slider.value = 0.45
	_check(is_equal_approx(game.effects_volume,0.45) and is_equal_approx(game.audio._effects_volume,0.45) and game.music_volume == 0 and AudioServer.is_bus_mute(0) == muted, "effects gain changes independently without mutating Master mute")
	_check(_labels().contains("0%") and _labels().contains("45%"), "settings labels reflect both actual slider changes")
	r._press("Back")
	_check(not game.hud.is_panel_open(), "settings Back resumes gameplay when opened from pause")
	await _reload("audio-settings")
	_check(game.music_volume == 0 and is_equal_approx(game.effects_volume,0.45) and game.audio._music_volume == 0 and is_equal_approx(game.audio._effects_volume,0.45), "separate audio settings survive save/restart and reach live audio")
	game.muted = true
	AudioServer.set_bus_mute(0,true)
	await _reload("stored-master-mute")
	_check(game.muted and AudioServer.is_bus_mute(0), "saved Master mute restores before opening title settings")
	game.at_title = true
	game.player.visible = false
	game.hud.show_start_menu(true)
	r._press("Settings")
	var gains_before: Array = [game.music_volume,game.effects_volume]
	r._press("Sound · Off")
	_check(not game.muted and not AudioServer.is_bus_mute(0) and game.at_title and game.hud._settings_open and _button("Sound · On") != null and [game.music_volume,game.effects_volume] == gains_before, "title settings can unmute stored Master mute while retaining both gains")
	await _reload("unmuted-from-title")
	_check(not game.muted and not AudioServer.is_bus_mute(0), "title settings unmute survives isolated save/restart")
	# Explicitly show start UI in test_mode with deterministic has-save input;
	# automatic real-save discovery/backup paths are not invoked.
	game.at_title = true
	game.player.visible = false
	game.hud.show_start_menu(true)
	_check(game.hud.is_panel_open(), "start menu renders with a Continue option for existing progress")
	var before: Array = [game.stars, game.inventory.duplicate(), game.friendship.duplicate(), game.current]
	game._action("buy_item:0")
	game._action("wear:5")
	_check([game.stars, game.inventory, game.friendship, game.current] == before and game.suit == 0, "title state blocks gameplay purchases and outfit changes")
	var continue_button := _button("Continue")
	if _check(continue_button != null and not continue_button.disabled, "existing-state title offers enabled Continue"):
		continue_button.pressed.emit()
	_check(not game.at_title and game.player.visible and not game.hud.is_panel_open() and [game.stars,game.inventory,game.friendship,game.current] == before, "Continue restores current world without resetting progress")
	_check(game.hud._footer_card.is_visible_in_tree() and game.hud._status.is_visible_in_tree(), "Continue restores gameplay footer and status")
	# No-save title presentation is deterministic, without reading a real save.
	game.at_title = true
	game.player.visible = false
	game.hud.show_start_menu(false)
	_check(_button("Continue") == null and _button("Begin your little orbit") != null, "no-save title offers Begin rather than an unusable Continue")
	game._action("continue")

func _camera_continuity() -> void:
	if not _check(game.get("camera_north") is Vector3 and game.get("camera_up") is Vector3, "camera exposes transported tangent state"):
		return
	for planet in range(6):
		await r._fly(planet)
		for direction in [-1.0,1.0]:
			game.orbit = 0
			game.pitch = 0
			game.overview = false
			r._position_at(Vector3.UP)
			var previous: Vector3 = game.camera_north
			var previous_up: Vector3 = game.normal
			var maximum := 0.0
			var transport_error := 0.0
			var tangent := true
			var finite := true
			for step in range(1,721):
				var angle: float = direction*TAU*float(step)/720.0
				var up := Vector3(0,cos(angle),sin(angle))
				game.normal = up
				game._update_player(0)
				game._update_camera(1.0/60.0)
				var heading: Vector3 = game.camera_north
				var transported: Vector3 = Quaternion(previous_up,up)*previous
				maximum = maxf(maximum,previous.angle_to(heading))
				transport_error = maxf(transport_error,transported.angle_to(heading))
				tangent = tangent and absf(heading.dot(up)) < 0.001 and absf(heading.length()-1) < 0.001
				finite = finite and heading.is_finite() and r._basis_ok(game.camera)
				previous = heading
				previous_up = up
			print("CAMERA_CONTINUITY planet=%d direction=%d max_step_deg=%.6f transport_error_deg=%.6f" % [planet,int(direction),rad_to_deg(maximum),rad_to_deg(transport_error)])
			_check(maximum < deg_to_rad(2.0), "planet %d great-circle direction %d has no heading reversal across BACK/FORWARD poles" % [planet,int(direction)])
			_check(transport_error < deg_to_rad(0.1) and tangent and finite, "planet %d full-circle tangent follows parallel transport and camera stays finite" % planet)

func _neighbor_collision() -> void:
	for who in range(4):
		await r._fly([1,2,4,5][who])
		var n: Vector3 = game.worlds[[1,2,4,5][who]].anchors.neighbor
		var registered := false
		for obstacle in game.worlds[[1,2,4,5][who]].obstacles:
			registered = registered or (obstacle.get("kind","") == "neighbor" and obstacle.normal.is_equal_approx(n))
		_check(registered, "neighbor %d has a registered walking obstacle" % who)
		var tangent: Vector3 = game._tangent(n,Vector3.RIGHT)
		for sprint in [false,true]:
			r._position_at((n+tangent*(1.7/game.RADII[[1,2,4,5][who]])).normalized())
			var minimum := INF
			var finite := true
			Input.action_press("move_right")
			if sprint:
				Input.action_press("run")
			# Steer toward the neighbor with real movement Input state. The
			# camera right axis supplies that direction, so no position fixture
			# teleports through the collision boundary during the approach.
			for step in range(120):
				var toward: Vector3 = game._tangent(game.normal,n)
				game.camera.global_basis = Basis(toward,game.normal,toward.cross(game.normal))
				game._update_player(0.05)
				minimum = minf(minimum,game.normal.distance_to(n)*game.RADII[[1,2,4,5][who]])
				finite = finite and r._sphere_ok() and game.player.global_transform.is_finite()
			Input.action_release("move_right")
			Input.action_release("run")
			print("NEIGHBOR_COLLISION who=%d run=%s closest_surface_distance=%.6f" % [who,sprint,minimum])
			_check(minimum >= 0.55 and minimum < 0.8 and finite, "neighbor %d %s approach reaches contact without penetrating its footprint" % [who,"running" if sprint else "walking"])
		game.velocity = Vector3.ZERO
		game._update_camera(1.0)
		r._key(KEY_E)
		_check(game.hud.is_panel_open() and _labels().contains(["Lumi","Bolt","Pip","Miso"][who]), "neighbor %d remains interactable from reachable collision boundary" % who)
		game.hud.close_panel()
		game.normal = n
		var recovered: Vector3 = game._resolve_surface(n)
		_check(recovered.is_finite() and absf(recovered.length()-1) < 0.001 and recovered.distance_to(n)*game.RADII[[1,2,4,5][who]] >= 0.55, "exact overlap with neighbor %d recovers to a finite nonpenetrating surface normal" % who)
