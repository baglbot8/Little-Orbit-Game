extends "res://tests/integration.gd"
## Headless adapter reuses runner helpers, overriding the full suite completely.
## Run with --headless --script res://tests/art_only.gd -- --integration --art-only.
## No save/load fixture writes or allow_test overrides.

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--integration" in args or not "--art-only" in args or DisplayServer.get_name() != "headless":
		printerr("ART_ONLY: requires headless --integration --art-only; refusing scene startup")
		quit(2)
		return
	for forbidden in ["--smoke-test","--capture","--gallery","--reel"]:
		if forbidden in args:
			printerr("ART_ONLY: refusing automatic mode "+forbidden)
			quit(2)
			return
	var art_checks = load("res://tests/art_pass_checks.gd")
	if not _check(art_checks != null and art_checks.can_instantiate(), "art checks compile"):
		quit(1)
		return
	var scene := load("res://main.tscn") as PackedScene
	if not _check(scene != null, "main scene loads"):
		quit(1)
		return
	game = scene.instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	await process_frame
	if _check(game.test_mode and not game.at_title and game.placed.is_empty(), "isolated save-free test_mode with fresh in-memory state"):
		if _check(game.worlds.size() == 6 and game.neighbors.size() == 4, "six generated worlds and four neighbors ready"):
			print("ART_ONLY_SCOPE: factories, batching, masks, building contact, descending entry levels")
			art_checks.new().run(self)
	for action in ["move_left","move_right","move_up","move_down","run"]:
		Input.action_release(action)
	game.audio.stop_all()
	await create_timer(0.3).timeout
	game.queue_free()
	await process_frame
	await process_frame
	print("ART_ONLY_RESULT: %d checks, %d failures" % [checks,failures.size()])
	for evidence in failures:
		printerr("CRITIC_EVIDENCE: "+evidence)
	quit(0 if failures.is_empty() else 1)
