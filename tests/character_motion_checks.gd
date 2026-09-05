extends SceneTree
## Technical invariants only; no scene/main loading, saves, or visual scoring.
## Run: godot --headless --path . --log-file /tmp/character-motion-checks.log --script res://tests/character_motion_checks.gd
const Art = preload("res://scripts/art.gd")
const Motion = preload("res://scripts/character_motion.gd")
const Neighbor = preload("res://scripts/neighbor_motion.gd")
const DT := 1.0 / 120.0
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_character()
	_neighbor(0)
	_neighbor(1)
	print("CHARACTER_MOTION_RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("MOTION_FAILURE: " + message)

func _place(model: Node3D) -> void:
	model.position = Vector3(2.5, -1.3, 4.2)
	model.rotation = Vector3(0.3, -0.7, 0.2)
	model.scale = Vector3(0.8, 1.2, 0.95)

func _character() -> void:
	var model := Art.astronaut()
	_place(model)
	var original := model.transform
	var motion := Motion.new()
	var legs: Array[Node3D] = []
	var parts: Array[Node3D] = []
	var rests: Array[Transform3D] = []
	var boot_start: Array[Vector3] = []
	for side in ["Left", "Right"]:
		var leg := model.get_node_or_null("Leg" + side) as Node3D
		_check(leg != null, side + " actual direct leg pivot exists")
		if leg == null:
			model.free()
			return
		legs.append(leg)
		for label in ["AnkleCuff", "Boot", "BootSole", "ToeGuard"]:
			var part := leg.get_node_or_null(NodePath(label)) as Node3D
			_check(part != null, side + " " + label + " is attached directly to leg")
			if part != null:
				parts.append(part)
				rests.append(part.transform)
		boot_start.append(leg.transform * (leg.get_node("Boot") as Node3D).position)
	motion.setup(model)
	_check(model.transform.is_equal_approx(original), "character setup preserves nonidentity root")
	_check(model.get_node("LegLeft") == legs[0] and model.get_node("LegRight") == legs[1], "setup reuses actual art pivots")
	var root_ok := true
	var attached := true
	var travel := [0.0, 0.0]
	var amplitude := [0.0, 0.0]
	var cycles := [0, 0]
	var phase_ok := true
	var pose_ok := true
	var previous_step := 0.0
	# Walk, run, walk: measure after two seconds of settling in each segment.
	for frame in range(2160):
		var running := frame >= 720 and frame < 1440
		var before: float = motion._phase
		var before_leg := legs[0].rotation.x
		motion.animate(10000.0 + frame * DT, true, false, DT, 1.0 if running else 0.0)
		var step := fposmod(motion._phase - before, TAU)
		phase_ok = phase_ok and step < 0.12 and absf(step - previous_step) < 0.012
		pose_ok = pose_ok and absf(legs[0].rotation.x - before_leg) < 0.10
		previous_step = step
		if frame % 720 >= 240 and frame < 1440:
			var slot := 1 if running else 0
			amplitude[slot] = maxf(amplitude[slot], absf(legs[0].rotation.x))
			if motion._phase < before:
				cycles[slot] += 1
		root_ok = root_ok and model.transform.is_equal_approx(original)
		for i in range(parts.size()):
			attached = attached and parts[i].transform.is_equal_approx(rests[i])
		for i in range(2):
			var boot := legs[i].get_node("Boot") as Node3D
			travel[i] = maxf(travel[i], (legs[i].transform * boot.position).distance_to(boot_start[i]))
	_check(root_ok, "character animation preserves root at every walk/run frame")
	_check(attached, "ankles, boots, soles and toe guards retain local attachment throughout swing")
	_check(travel[0] > 0.05 and travel[1] > 0.05, "both boots actually travel with leg swing")
	_check(amplitude[0] > 0.15 and amplitude[1] > amplitude[0] * 1.4, "settled run stride exceeds walk stride by at least 40%")
	_check(cycles[1] > cycles[0], "run cadence exceeds walk cadence")
	_check(phase_ok, "phase advances continuously through walk/run/walk and wraparound")
	_check(pose_ok, "actual leg pose has no frame snap through speed transitions")
	print("MOTION_METRICS: walk amplitude %.4f, run %.4f; cycles %d/%d; boot travel %.4f/%.4f" % [amplitude[0], amplitude[1], cycles[0], cycles[1], travel[0], travel[1]])
	# Changing the absolute clock must not change the gait (head idle may use it).
	var other := Art.astronaut()
	var other_motion := Motion.new()
	other_motion.setup(other)
	motion.setup(model)
	var clock_independent := true
	for frame in range(360):
		motion.animate(frame * DT, true, false, DT, 0.5)
		other_motion.animate(90000.0 + frame * DT, true, false, DT, 0.5)
		clock_independent = clock_independent and is_equal_approx(motion._phase, other_motion._phase)
	_check(clock_independent, "accumulated gait phase is independent of absolute world time")
	for frame in range(600):
		motion.animate(frame * DT, false, frame < 90, DT)
		root_ok = root_ok and model.transform.is_equal_approx(original)
	_check(root_ok, "jump and idle preserve root")
	_check(absf(motion.bob) < 0.001 and absf(motion.lean) < 0.001 and absf(motion.sway) < 0.001, "body offsets settle after landing and stopping")
	_check(legs[0].rotation.length() < 0.001 and legs[1].rotation.length() < 0.001, "legs settle to rest after landing")
	other.free()
	model.free()

func _neighbor(index: int) -> void:
	var model: Node3D = Art.alien() if index == 0 else Art.robot()
	var label := "Lumi" if index == 0 else "Bolt"
	_place(model)
	var original := model.transform
	var eyes: Array[Node3D] = []
	var scales: Array[Vector3] = []
	for side in ["Left", "Right"]:
		var eye := model.get_node_or_null("HeadRig/Eye" + side) as Node3D
		_check(eye != null and eye.get_child_count() > 0, label + " actual " + side + " eye rig has geometry")
		if eye == null:
			model.free()
			return
		# Exercise preservation of authored scales other than Vector3.ONE.
		eye.scale *= Vector3(0.9, 1.15, 0.8)
		eyes.append(eye)
		scales.append(eye.scale)
	var arm := model.get_node("ArmRight") as Node3D
	arm.rotation += Vector3(0.03, -0.02, 0.04)
	var arm_rest := arm.transform
	var motion := Neighbor.new()
	motion.setup(model, index)
	_check(model.transform.is_equal_approx(original), label + " setup preserves root")
	motion.greet()
	var closed := [false, false]
	var reopened := [false, false]
	var root_ok := true
	var scale_ok := true
	var peak_wave := 0.0
	for frame in range(600):
		motion.animate(frame * DT, DT)
		root_ok = root_ok and model.transform.is_equal_approx(original)
		peak_wave = maxf(peak_wave, absf(arm.rotation.z - arm_rest.basis.get_euler().z))
		for i in range(eyes.size()):
			var eye := eyes[i]
			var ratio := eye.scale.y / scales[i].y
			closed[i] = closed[i] or ratio < 0.12
			reopened[i] = reopened[i] or (closed[i] and eye.scale.is_equal_approx(scales[i]))
			scale_ok = scale_ok and is_equal_approx(eye.scale.x, scales[i].x) and is_equal_approx(eye.scale.z, scales[i].z)
			# Verify real geometry inherits the squash, rather than only timer state.
			var mesh := eye.get_child(0) as Node3D
			var height := (eye.transform * mesh.transform).basis.y.length()
			scale_ok = scale_ok and is_equal_approx(height, scales[i].y * ratio * mesh.scale.y)
	_check(root_ok, label + " blink/greeting preserves root every frame")
	_check(closed[0] and closed[1] and reopened[0] and reopened[1], label + " both actual eyes close below 12% and reopen to authored scales")
	_check(scale_ok, label + " eye geometry inherits Y closure while X/Z rest scales survive")
	_check(peak_wave > 1.0, label + " greet moves actual arm")
	_check(arm.transform.is_equal_approx(arm_rest), label + " greeting returns arm to nonzero authored rest")
	model.free()
