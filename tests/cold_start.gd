extends SceneTree
## Run ONLY in the unique /tmp QA project described in POLISH_FUNCTIONAL_REVIEW.
## This deliberately exercises non-test production saves/settings/backups.
## Fail closed before any user:// IO unless the QA project AND OS data-dir
## name are verified. Never run this against the Little Orbit project itself.

var game: Node
var checks := 0
var failures: Array[String] = []
var qa_verified := false
const SAVE := "user://orbit_save.json"
const BACKUP := "user://orbit_save.backup.json"
const SETTINGS := "user://orbit_settings.json"

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, evidence: String) -> bool:
	checks += 1
	if not ok:
		failures.append(evidence)
		printerr("COLD_ASSERTION: " + evidence)
	return ok

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var name_text := str(ProjectSettings.get_setting("application/config/name", ""))
	var project_path := ProjectSettings.globalize_path("res://")
	var data_path := OS.get_user_data_dir().simplify_path()
	qa_verified = name_text.begins_with("LittleOrbitQA-") and name_text.trim_prefix("LittleOrbitQA-").is_valid_int() and data_path.get_file() == name_text and not data_path.ends_with("/Little Orbit") and (project_path.begins_with("/tmp/little-orbit-cold-") or project_path.begins_with("/private/tmp/little-orbit-cold-"))
	if not qa_verified or not "--cold-start-qa" in args or "--integration" in args or "--smoke-test" in args or "--capture" in args or "--gallery" in args or "--reel" in args:
		printerr("COLD_REFUSED: requires unique /tmp LittleOrbitQA-<numeric-id> project and matching OS user-data directory, with --cold-start-qa only. No save IO performed.")
		quit(2)
		return
	print("COLD_QA_PROJECT: ",project_path," DATA: ",data_path," NAME: ",name_text)
	for path in [SAVE, BACKUP, SETTINGS, SAVE+".tmp", SETTINGS+".tmp"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			printerr("COLD_REFUSED: QA fixture was already used: ",path,"; no save IO performed.")
			quit(2)
			return
	if not await _boot():
		await _finish()
		return
	_check(not game.save_available and _button("Continue") == null and _button("Begin your little orbit") != null, "cold empty directory offers Begin and no Continue")
	game._process(21.0)
	game._save_game()
	_check(not FileAccess.file_exists(SAVE), "title autosave interval and explicit save do not create a game save")
	_press("Settings")
	var music := game.hud.find_child("MusicSlider",true,false) as HSlider
	var effects := game.hud.find_child("EffectsSlider",true,false) as HSlider
	if _check(music != null and effects != null, "cold title opens both real settings sliders"):
		music.value = 0.29
		effects.value = 0.41
	_check(FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS+".tmp") and not FileAccess.file_exists(SAVE), "title settings write only the separate settings file atomically")
	_press("Sound · On")
	_check(game.muted and AudioServer.is_bus_mute(0) and _button("Sound · Off") != null, "title sound toggle stores Master mute and refreshes its label")
	var settings_bytes := FileAccess.get_file_as_string(SETTINGS)
	var settings = JSON.parse_string(settings_bytes)
	_check(settings is Dictionary and is_equal_approx(float(settings.get("music",-1)),0.29) and is_equal_approx(float(settings.get("effects",-1)),0.41), "actual settings JSON contains the two chosen gains")
	_press("Back")
	_check(game.at_title and game.hud.is_panel_open() and not FileAccess.file_exists(SAVE), "settings Back returns to title without manufacturing a save")
	await _shutdown_game()
	var seed_data := {"version":1,"stars":211,"inventory":[3,0,4,2,1,5,2,1,1,0,1,1,2,0,1,1,2,4],"favors":[1,1],"friendship":[1,5],"cargo":[false,false],"quest_round":[1,5],"quest_progress":[1,0],"collected_bits":[1,0],"talk_counts":[17,23],"wishes":8,"suit":5,"planet":2,"normal":[0,1,0.35],"overview":true,"music_volume":0.81,"effects_volume":0.82,"placed":[{"kind":17,"n":[0,-1,0],"angle":0.5},{"kind":3,"n":[1,0,0],"angle":1.0}]}
	var seed_bytes := JSON.stringify(seed_data,"\t")+"\n"
	_write(SAVE,seed_bytes)
	if not await _boot():
		await _finish()
		return
	_check(game.save_available and _button("Continue") != null and _button("New game") != null, "valid real save enables cold Continue and New game")
	_check(game.stars == 211 and game.current == 2 and game.friendship == [1,5,0,0] and game.placed_nodes.size() == 2 and game.suit == 5, "cold production loader reconstructs actual saved gameplay")
	_check(is_equal_approx(game.music_volume,0.29) and is_equal_approx(game.effects_volume,0.41) and is_equal_approx(game.audio._music_volume,0.29) and is_equal_approx(game.audio._effects_volume,0.41), "separate cold settings override older game-save gains and reach live audio")
	_check(game.muted and AudioServer.is_bus_mute(0), "real cold settings restore stored Master mute")
	_press("Settings")
	_press("Sound · Off")
	_check(game.at_title and not game.muted and not AudioServer.is_bus_mute(0) and _button("Sound · On") != null and is_equal_approx(game.music_volume,0.29) and is_equal_approx(game.effects_volume,0.41), "cold title settings unmute stored Master mute without changing either gain")
	settings_bytes = FileAccess.get_file_as_string(SETTINGS)
	settings = JSON.parse_string(settings_bytes)
	_check(settings is Dictionary and settings.get("muted",true) == false and FileAccess.get_file_as_string(SAVE) == seed_bytes, "title unmute persists to real settings only, preserving game-save bytes")
	_press("Back")
	game._process(21.0)
	game._save_game()
	_check(FileAccess.get_file_as_string(SAVE) == seed_bytes, "title cannot overwrite an existing save even after autosave interval")
	_press("Continue")
	_check(not game.at_title and game.player.visible and not game.hud.is_panel_open() and game.stars == 211 and game.current == 2 and game.placed.size() == 2, "real Continue resumes exactly the loaded world")
	game._action("title")
	_check(game.at_title and game.save_available and _button("Continue") != null, "return to start saves progress and keeps valid Continue")
	var previous_bytes := FileAccess.get_file_as_string(SAVE)
	var old_refs: Array[WeakRef] = []
	for node in game.placed_nodes:
		old_refs.append(weakref(node))
	for pickup in game.pickups:
		old_refs.append(weakref(pickup.node))
	_press("New game")
	_check(_button("Keep my current orbit") != null and _button("Start a new orbit") != null, "existing-save New game requires explicit confirmation")
	_check(FileAccess.get_file_as_string(SAVE) == previous_bytes and not FileAccess.file_exists(BACKUP), "opening confirmation does not write save or backup")
	_press("Keep my current orbit")
	_check(game.at_title and game.stars == 211 and game.friendship == [1,5,0,0] and game.placed_nodes.size() == 2 and FileAccess.get_file_as_string(SAVE) == previous_bytes and not FileAccess.file_exists(BACKUP), "cancel preserves in-memory progress and exact saved bytes")
	_press("New game")
	_press("Start a new orbit")
	await process_frame
	await process_frame
	_check(FileAccess.file_exists(BACKUP) and FileAccess.get_file_as_string(BACKUP) == previous_bytes, "confirmed reset backs up the previous save byte-for-byte")
	var released := true
	for reference in old_refs:
		released = released and reference.get_ref() == null
	_check(released and game.placed_nodes.is_empty() and game.placed.is_empty(), "confirmed real reset frees prior decoration and collectible nodes")
	_check(not game.at_title and game.stars == 30 and game.inventory == [2,1,1,1,1,2,0,0,0,0,0,0,0,0,0,0,0,0] and game.friendship == [0,0,0,0] and game.quest_progress == [0,0,0,0] and game.current == 0 and game.pickups.size() == 8, "confirmed real reset starts a clean playable neighborhood")
	var reset_data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	print("COLD_RESET_DISK: ",JSON.stringify(reset_data))
	# JSON numeric arrays decode as floats. Compare their numeric contents,
	# not Array's strict element-type identity against an integer literal.
	_check(reset_data is Dictionary and int(reset_data.stars) == 30 and PackedInt32Array(reset_data.friendship) == PackedInt32Array([0,0,0,0]) and PackedInt32Array(reset_data.quest_round) == PackedInt32Array([0,0,0,0]) and reset_data.placed.is_empty() and int(reset_data.suit) == 0, "real post-reset save contains fresh progress rather than the old state")
	_check(FileAccess.get_file_as_string(SETTINGS) == settings_bytes and is_equal_approx(game.music_volume,0.29), "new game preserves separate settings bytes and live preference")
	await _shutdown_game()
	if not await _boot():
		await _finish()
		return
	_check(game.save_available and game.stars == 30 and game.placed_nodes.is_empty() and game.pickups.size() == 8 and is_equal_approx(game.effects_volume,0.41), "another cold boot reads the reset save and separate settings consistently")
	_check(not game.muted and not AudioServer.is_bus_mute(0), "title unmute remains effective after real reset and another cold boot")
	_check(FileAccess.get_file_as_string(BACKUP) == previous_bytes, "cold boot does not modify the backup")
	# Block only the QA staging filename, then exercise the actual title/quit
	# failure UX. No filesystem permission assumptions are needed.
	_press("Continue")
	var protected_bytes := FileAccess.get_file_as_string(SAVE)
	_check(DirAccess.make_dir_absolute(SAVE+".tmp") == OK, "QA-only save staging obstruction created")
	_check(not game._save_game(), "real failed save returns false")
	game._action("title")
	_check(not game.at_title and game.player.visible and FileAccess.get_file_as_string(SAVE) == protected_bytes, "failed save refuses title transition and preserves the existing save")
	game._action("quit")
	_check(not game.closing and _button("Stay in my orbit") != null and _button("Quit without saving") != null, "failed quit save presents Stay and explicit Quit without saving")
	_press("Stay in my orbit")
	_check(not game.hud.is_panel_open() and not game.closing and not game.at_title, "Stay after failed quit keeps the current game open")
	_check(DirAccess.remove_absolute(SAVE+".tmp") == OK, "QA-only save staging obstruction removed")
	_check(game._save_game(), "saving recovers when the staging obstruction is removed")
	game._action("title")
	# Force a real copy error using an empty directory at this QA-only path.
	DirAccess.remove_absolute(BACKUP)
	_check(DirAccess.make_dir_absolute(BACKUP) == OK, "QA-only backup obstruction is created")
	var guarded_bytes := FileAccess.get_file_as_string(SAVE)
	game.stars = 91
	game._action("confirm_new_game")
	_check(game.stars == 91 and game.at_title and FileAccess.get_file_as_string(SAVE) == guarded_bytes, "backup failure aborts reset and preserves memory and saved bytes")
	_check(_labels().contains("could not be backed up"), "backup failure explains that existing progress was kept")
	_check(DirAccess.remove_absolute(BACKUP) == OK, "QA backup obstruction removed")
	await _shutdown_game()
	_write(SAVE,"{ invalid saved data")
	if await _boot():
		_check(not game.save_available and _button("Continue") == null and _button("Begin your little orbit") != null, "malformed existing file is not mistaken for a valid Continue save")
		game._save_game()
		_check(FileAccess.get_file_as_string(SAVE) == "{ invalid saved data", "title preserves malformed save bytes for recovery")
	await _finish()

func _write(path: String, bytes: String) -> void:
	assert(qa_verified)
	var file := FileAccess.open(path,FileAccess.WRITE)
	if _check(file != null,"QA fixture opens: "+path):
		file.store_string(bytes)
		file.close()

func _boot() -> bool:
	assert(qa_verified)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	return _check(game.test_mode == false and game.at_title and not game.player.visible and game.hud != null and game.worlds.size() == 6,"production cold ready reaches title in verified QA directory")

func _button(prefix: String) -> Button:
	for node in game.hud.find_children("*","Button",true,false):
		if node.is_visible_in_tree() and node.text.begins_with(prefix):
			return node
	return null

func _press(prefix: String) -> void:
	var button := _button(prefix)
	if _check(button != null and not button.disabled,"enabled actual UI choice: "+prefix):
		button.pressed.emit()

func _labels() -> String:
	var text := ""
	for label in game.hud.find_children("*","Label",true,false):
		if label.is_visible_in_tree():
			text += label.text+"\n"
	return text

func _shutdown_game() -> void:
	if is_instance_valid(game):
		if is_instance_valid(game.audio):
			game.audio.stop_all()
		game.queue_free()
		await process_frame
		await process_frame
	game = null

func _finish() -> void:
	await _shutdown_game()
	if qa_verified:
		for path in [SAVE,BACKUP,SETTINGS,SAVE+".tmp",SETTINGS+".tmp"]:
			if FileAccess.file_exists(path):
				_check(DirAccess.remove_absolute(path) == OK,"remove QA-owned file: "+path)
			elif DirAccess.dir_exists_absolute(path):
				_check(DirAccess.remove_absolute(path) == OK,"remove empty QA-owned directory: "+path)
	# Observe audio mixer cleanup; no warning suppression or player-save writes.
	await create_timer(0.3).timeout
	print("COLD_START_RESULT: %d checks, %d failures" % [checks, failures.size()])
	for evidence in failures:
		printerr("COLD_EVIDENCE: "+evidence)
	quit(0 if failures.is_empty() else 1)
