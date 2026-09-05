extends SceneTree
const Sound = preload("res://scripts/audio.gd")
const Motion = preload("res://scripts/character_motion.gd")
const Art = preload("res://scripts/art.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("UPDATE_FAILURE: " + message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var sound := Sound.new()
	root.add_child(sound)
	check(sound._syllables.size() == 24, "four speakers each have six cached syllables")
	var fingerprints := {}
	for sample in sound._syllables:
		var data: PackedByteArray = sample.data
		var peak := 0
		for i in range(0, data.size(), 2):
			peak = maxi(peak, absi(data.decode_s16(i)))
		check(peak > 4000 and peak < 30000, "syllable audible without clipping")
		check(data.decode_s16(0) == 0 and data.decode_s16(data.size() - 2) == 0, "gated endpoints silent")
		check(sample.get_length() < 0.12, "short syllable")
		fingerprints[hash(data)] = true
	check(fingerprints.size() == 24, "all speaker/variant buffers distinct")
	sound.resume_on_user_gesture()
	sound.play_voice(0, 0)
	var first: AudioStream = sound._dialogue.stream
	check(first == sound._syllables[0], "playback uses cached buffer")
	sound.play_voice(1, 2)
	check(sound._dialogue.stream == first, "rapid blips do not interrupt or overlap")
	await create_timer(0.06).timeout
	sound.stop_voice()
	first = null
	check(not sound._dialogue.playing and sound._dialogue.stream == null, "stop releases current playback")
	for speaker in range(4):
		sound.play_voice(speaker, 0)
		check(sound._dialogue.stream == sound._syllables[speaker * 6], "speaker mapping")
		await create_timer(0.04).timeout
		sound.stop_voice()
	sound.play_voice(8, 0)
	check(sound._dialogue.stream == null, "invalid speaker ignored")
	sound.play_voice(0, -1)
	check(sound._dialogue.stream == null, "negative text offset ignored")
	sound.set_effects_volume(0.5)
	check(is_equal_approx(db_to_linear(sound._dialogue.volume_db), 0.5), "voice follows effects volume")
	sound.play_voice(0, 2)
	await create_timer(0.04).timeout
	sound.set_effects_volume(0)
	check(sound._dialogue.stream == null, "zero effects stops voice")
	sound.set_effects_volume(0.5)
	AudioServer.set_bus_mute(0, true)
	sound.play_voice(0, 3)
	check(sound._dialogue.stream == null, "master mute suppresses blips")
	AudioServer.set_bus_mute(0, false)
	sound.stop_all()
	sound.stop_all()
	sound.resume_on_user_gesture()
	sound.play_voice(0, 0)
	check(sound._dialogue.stream == null and sound._syllables.is_empty() and not sound._ambient.playing, "shutdown terminal and idempotent")
	sound.queue_free()
	motion_checks()
	# Let the audio mixer release stopped PCM playback references before exit.
	await create_timer(0.15).timeout
	print("MOTION_AUDIO_UPDATE_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func motion_checks() -> void:
	var model := Art.astronaut()
	model.transform = Transform3D(Basis.from_euler(Vector3(0.1, 0.4, 0.2)).scaled(Vector3(0.8, 1.2, 0.9)), Vector3(1, 2, 3))
	var original := model.transform
	var arm := model.get_node("ArmLeft") as Node3D
	var mitten := arm.get_node("Mitten") as Node3D
	var mitten_rest := arm.transform * mitten.transform
	var motion := Motion.new()
	motion.setup(model)
	var elbow := arm.get_node("ElbowRig") as Node3D
	check((arm.transform * elbow.transform * mitten.transform).is_equal_approx(mitten_rest), "runtime elbow preserves authored attachment before entering scene")
	var child_count := arm.get_child_count()
	var peak_twist := 0.0
	var counter_rotation := false
	var elbow_peak := 0.0
	for frame in range(720):
		motion.animate(frame / 120.0, true, false, 1.0 / 120.0, 1)
		peak_twist = maxf(peak_twist, absf(motion.twist))
		elbow_peak = maxf(elbow_peak, absf(elbow.rotation.x))
		counter_rotation = counter_rotation or motion.twist * (model.get_node("LegLeft") as Node3D).rotation.y < -0.003
	var pose := elbow.transform
	motion.setup(model)
	check(arm.get_child_count() == child_count and arm.get_node("ElbowRig") == elbow and elbow.transform.is_equal_approx(pose), "setup while running reuses elbow without snapping")
	check(peak_twist > 0.05 and counter_rotation, "body and hips counterrotate during run")
	check(elbow_peak > 0.45, "run bends actual forearm")
	for frame in range(720):
		motion.animate(frame / 120.0, false, frame < 60, 1.0 / 120.0)
	check(absf(motion.twist) < 0.001 and elbow.rotation.length() < 0.001, "jump/land/idle settle elbow and twist")
	check(model.transform.is_equal_approx(original), "root rest transform survives animation and repeated setup")
	model.free()
