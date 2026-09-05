class_name CharacterMotion
extends RefCounted
## Instance controller for PlanetArt.astronaut(). Works before or after add_child().
## Pivots: ArmLeft/ArmRight at shoulders, LegLeft/LegRight at hips.
## Left is the character's left (-X when facing +Z). Root transforms are untouched.

const WALK_SPEED := 7.0
const RESPONSE := 10.0

var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _head: Node3D
var _phase := 0.0
var _move := 0.0
var _run := 0.0
var _air := 0.0
var _air_time := 0.0
# Main applies these offsets to the avatar, relative to its own rest transform.
var bob: float = 0.0
var lean: float = 0.0
var sway: float = 0.0
var twist: float = 0.0


func _rest(node: Node3D) -> Vector3:
	if not node.has_meta("character_motion_rest"):
		node.set_meta("character_motion_rest", node.rotation)
	return node.get_meta("character_motion_rest")


func setup(model: Node3D) -> void:
	_arms.clear()
	_legs.clear()
	_elbows.clear()
	_head = null
	_phase = 0.0
	_move = 0.0
	_run = 0.0
	_air = 0.0
	_air_time = 0.0
	bob = 0.0
	lean = 0.0
	sway = 0.0
	twist = 0.0
	if not is_instance_valid(model):
		return
	for side in [-1.0, 1.0]:
		var suffix := "Left" if side < 0.0 else "Right"
		_arms.append(_pivot(model, "Arm" + suffix,
			Vector3(side * 0.21, 0.52, 0),
			["Sleeve", "Mitten"],
			[Vector3(side * 0.25, 0.43, 0.02), Vector3(side * 0.29, 0.32, 0.055)]))
		_legs.append(_pivot(model, "Leg" + suffix,
			Vector3(side * 0.12, 0.34, 0),
			["Leg", "Boot"],
			[Vector3(side * 0.12, 0.23, 0), Vector3(side * 0.13, 0.085, 0.04)]))

	for arm in _arms:
		_elbows.append(_elbow(arm))
	for limb in _arms + _legs:
		_rest(limb)
	_head = model.get_node_or_null("HeadRig") as Node3D
	if _head != null:
		_rest(_head)


func _elbow(arm: Node3D) -> Node3D:
	var existing := arm.get_node_or_null("ElbowRig") as Node3D
	if existing != null:
		return existing
	var pivot := Node3D.new()
	pivot.name = "ElbowRig"
	# Pivot just below shoulder, with the authored sleeve as a rigid forearm.
	# This preserves every mesh rest transform and avoids a torn sleeve seam.
	pivot.position = Vector3(0, -0.02, 0)
	arm.add_child(pivot)
	for label in ["Sleeve", "WristCuff", "Mitten", "Thumb"]:
		var part := arm.get_node_or_null(NodePath(label)) as Node3D
		if part == null:
			continue
		var rest := part.transform
		arm.remove_child(part)
		pivot.add_child(part)
		part.transform = pivot.transform.affine_inverse() * rest
	_rest(pivot)
	return pivot


func _pivot(model: Node3D, label: String, origin: Vector3,
		part_names: Array, rest_positions: Array) -> Node3D:
	# Reusing the named pivot makes repeated setup safe, including while walking.
	var existing := model.get_node_or_null(NodePath(label)) as Node3D
	if existing != null:
		return existing
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = origin
	model.add_child(pivot)
	var parts: Array[Node3D] = []
	for child in model.get_children():
		if not child is MeshInstance3D:
			continue
		var part := child as Node3D
		if part.position.x * origin.x <= 0.0:
			continue
		for i in range(part_names.size()):
			# Godot may replace duplicate mesh names with @MeshInstance3D@<id>.
			# Rest positions identify those anonymous siblings without relying on IDs.
			var named := String(part.name).begins_with(String(part_names[i]))
			var anonymous := String(part.name).begins_with("@")
			if named or (anonymous and part.position.is_equal_approx(rest_positions[i])):
				parts.append(part)
				break
	for part in parts:
		# Local math also works outside the scene tree, unlike global_transform.
		var rest := part.transform
		model.remove_child(part)
		pivot.add_child(part)
		part.transform = pivot.transform.affine_inverse() * rest
	return pivot


func animate(time: float, moving: bool, airborne: bool, delta: float, run_amount: float = 0.0) -> void:
	if not is_finite(time) or not is_finite(delta) or delta <= 0.0:
		return
	var dt := minf(delta, 0.1)
	var blend := 1.0 - exp(-RESPONSE * dt)
	var run_target := clampf(run_amount, 0.0, 1.0) if is_finite(run_amount) else 0.0
	_run = lerpf(_run, run_target, blend)
	_move = lerpf(_move, 1.0 if moving else 0.0, blend)
	_air = lerpf(_air, 1.0 if airborne else 0.0, blend)
	_air_time = _air_time + dt if airborne else 0.0
	# Integrating frequency keeps walk/run transitions continuous at any world time.
	_phase = fmod(_phase + dt * lerpf(WALK_SPEED, 11.5, _run) * _move, TAU)
	var ground := _move * (1.0 - _air)
	var stride := sin(_phase) * ground
	var tuck := sin(minf(_air_time * 4.0, PI)) * 0.14
	for i in range(_arms.size()):
		var side := -1.0 if i == 0 else 1.0
		# A second harmonic gives a quick recovery and longer backward push.
		var leg_phase := _phase + (PI if i == 0 else 0.0)
		var swing := sin(leg_phase) + _run * 0.24 * sin(2.0 * leg_phase + 0.45)
		var hip_turn := cos(_phase) * lerpf(0.025, 0.11, _run) * ground
		var arm_target := Vector3(-swing * ground * lerpf(0.30, 0.74, _run),
			stride * 0.035, side * (0.025 + _run * ground * 0.04))
		var leg_target := Vector3(swing * ground * lerpf(0.38, 0.90, _run), -hip_turn, -sway * 0.35)
		arm_target = arm_target.lerp(Vector3(-0.32 - tuck, 0, side * 0.22), _air)
		leg_target = leg_target.lerp(Vector3(0.16 + tuck + side * 0.07, 0, side * 0.035), _air)
		if i < _elbows.size() and is_instance_valid(_elbows[i]):
			var bend := -ground * lerpf(0.08, 0.62 + 0.18 * cos(leg_phase), _run) - _air * 0.35
			_elbows[i].rotation = _elbows[i].rotation.lerp(_rest(_elbows[i]) + Vector3(bend, 0, 0), blend)
		if is_instance_valid(_arms[i]):
			_arms[i].rotation = _arms[i].rotation.lerp(_rest(_arms[i]) + arm_target, blend)
		if i < _legs.size() and is_instance_valid(_legs[i]):
			_legs[i].rotation = _legs[i].rotation.lerp(_rest(_legs[i]) + leg_target, blend)
	bob = lerpf(bob, (1.0 - cos(_phase * 2.0)) * lerpf(0.014, 0.028, _run) * ground, blend)
	lean = lerpf(lean, lerpf(0.025, 0.13, _run) * ground - 0.035 * _air, blend)
	sway = lerpf(sway, sin(_phase) * lerpf(0.025, 0.045, _run) * ground, blend)
	twist = lerpf(twist, cos(_phase) * lerpf(0.025, 0.10, _run) * ground, blend)
	if is_instance_valid(_head):
		var idle := (1.0 - _move) * (1.0 - _air)
		var head_target := Vector3(sin(time * 1.1) * 0.018 * idle - lean * 0.35,
			sin(time * 0.57) * 0.045 * idle - twist * 0.65, sin(time * 0.83) * 0.02 * idle - sway * 0.3)
		_head.rotation = _head.rotation.lerp(_rest(_head) + head_target, blend)
