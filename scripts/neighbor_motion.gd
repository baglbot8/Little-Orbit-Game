class_name NeighborMotion
extends RefCounted
## Animates local rig parts only; surface placement and root scale belong to main.

var _head: Node3D
var _arm: Node3D
var _eyes: Array[Node3D] = []
var _antennae: Array[Node3D] = []
var _index := 0
var _clock := 0.0
var _blink_at := 2.1
var _blink_age := -1.0
var _wave_at := 5.0
var _wave_age := -1.0
var _attention := 0.0
var _was_engaged := false


func setup(model: Node3D, index: int) -> void:
	_head = null
	_arm = null
	_eyes.clear()
	_antennae.clear()
	_index = index
	_clock = 0.0
	_blink_at = 2.1 + index * 0.83
	_blink_age = -1.0
	_wave_at = 5.0 + index * 3.7
	_wave_age = -1.0
	_attention = 0.0
	_was_engaged = false
	if not is_instance_valid(model):
		return
	_head = model.get_node_or_null("HeadRig") as Node3D
	_arm = model.get_node_or_null("ArmRight") as Node3D
	# Older art had direct mesh children. Group the original pieces using local
	# transforms so setup also works before the model enters the scene tree.
	if _head == null:
		_head = _legacy_pivot(model, "HeadRig", Vector3(0, 0.59, 0), true)
	if _arm == null:
		_arm = _legacy_pivot(model, "ArmRight", Vector3(0.22, 0.44, 0), false)
	for label in ["EyeLeft", "EyeRight"]:
		var eye := _head.find_child(label, true, false) as Node3D
		if eye != null:
			_eyes.append(eye)
	if _eyes.is_empty():
		for child in _head.get_children():
			var part := child as Node3D
			if part == null:
				continue
			var label := String(part.name)
			var old_position := _head.transform * part.position
			if label.begins_with("Eye") or label.begins_with("PixelEye") or (
				label.begins_with("@") and old_position.z > 0.17 and
				absf(old_position.x) < 0.15 and old_position.y > 0.69 and old_position.y < 0.79):
				_eyes.append(part)
	# Only animate explicit antenna pivots, never individual pearls or rod meshes.
	for label in ["AntennaLeft", "AntennaRight", "AntennaRig", "AerialRig"]:
		var antenna := _head.find_child(label, true, false) as Node3D
		if antenna != null and not antenna is MeshInstance3D:
			_antennae.append(antenna)
	for part in [_head, _arm] + _antennae:
		_rest_rotation(part)
	for eye in _eyes:
		if not eye.has_meta("neighbor_motion_scale"):
			eye.set_meta("neighbor_motion_scale", eye.scale)
		eye.scale = eye.get_meta("neighbor_motion_scale")


func _legacy_pivot(model: Node3D, label: String, origin: Vector3, head: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = origin
	var parts: Array[Node3D] = []
	for child in model.get_children():
		var part := child as Node3D
		if part == null or part is Label3D:
			continue
		var p := part.position
		if (head and p.y >= 0.60) or (not head and p.x > 0.18 and p.y >= 0.23 and p.y <= 0.46):
			parts.append(part)
	model.add_child(pivot)
	for part in parts:
		var rest := part.transform
		model.remove_child(part)
		pivot.add_child(part)
		part.transform = pivot.transform.affine_inverse() * rest
	return pivot


func _rest_rotation(part: Node3D) -> Vector3:
	if not part.has_meta("neighbor_motion_rotation"):
		part.set_meta("neighbor_motion_rotation", part.rotation)
	return part.get_meta("neighbor_motion_rotation")


func greet() -> void:
	# Repeated interaction during a hello does not snap the hand back down.
	if _wave_age < 0.0:
		_wave_age = 0.0
	_wave_at = _clock + 12.0 + _index * 2.3


func animate(time: float, delta: float, engaged: bool = false) -> void:
	if not is_finite(time) or not is_finite(delta) or delta <= 0.0:
		return
	var dt := minf(delta, 0.1)
	_clock += dt
	var mechanical := _index == 1 or _index == 3
	# Pip looks around eagerly; Miso uses a slower, rounded servo greeting.
	var baker := _index == 3
	var blend := 1.0 - exp(-(13.0 if mechanical else 5.5) * dt)
	_attention = lerpf(_attention, 1.0 if engaged else 0.0, blend)
	if engaged and not _was_engaged:
		greet()
	_was_engaged = engaged
	if _clock >= _wave_at:
		greet()
	var wave := 0.0
	var flutter := 0.0
	if _wave_age >= 0.0:
		_wave_age += dt
		var duration := 2.35 if baker else (1.65 if mechanical else 2.2)
		wave = smoothstep(0.0, 0.32, _wave_age) * (1.0 - smoothstep(duration - 0.45, duration, _wave_age))
		flutter = sin(_wave_age * (8.0 if baker else (15.0 if mechanical else 10.0)))
		if _wave_age >= duration:
			_wave_age = -1.0
	if is_instance_valid(_arm):
		var target := Vector3(-0.18 * wave, 0.10 * flutter * wave,
			(2.25 + flutter * (0.16 if mechanical else 0.26)) * wave)
		_arm.rotation = _arm.rotation.lerp(_rest_rotation(_arm) + target, blend)
	if is_instance_valid(_head):
		var phase := _clock + _index * 2.7
		var curiosity := sin(phase * 0.63) * 0.055
		if _index == 2:
			curiosity *= 1.35
		if mechanical and not baker:
			curiosity = snappedf(curiosity, 0.025)
		var target := Vector3(sin(phase * 1.3) * 0.014 + _attention * 0.035,
			curiosity * (1.0 - _attention * 0.65),
			curiosity * (0.45 if mechanical else 0.9) + _attention * 0.045)
		_head.rotation = _head.rotation.lerp(_rest_rotation(_head) + target, blend)
	for i in range(_antennae.size()):
		var antenna := _antennae[i]
		if is_instance_valid(antenna):
			var offset := Vector3(sin(_clock * 2.3 + i) * 0.025, 0,
				sin(_clock * 1.7 + i * 2.0) * (0.018 if mechanical else 0.045))
			antenna.rotation = antenna.rotation.lerp(_rest_rotation(antenna) + offset, blend)
	if _clock >= _blink_at and _blink_age < 0.0:
		_blink_age = 0.0
		_blink_at = _clock + 3.2 + _index * 0.7 + (sin(_clock * 1.73) + 1.0) * 0.8
	var openness := 1.0
	if _blink_age >= 0.0:
		_blink_age += dt
		var duration := 0.16 if mechanical else 0.22
		var progress := clampf(_blink_age / duration, 0.0, 1.0)
		openness = 1.0 - 0.94 * sin(progress * PI)
		if _blink_age >= duration:
			_blink_age = -1.0
			openness = 1.0
	for eye in _eyes:
		if is_instance_valid(eye):
			var rest: Vector3 = eye.get_meta("neighbor_motion_scale")
			eye.scale = Vector3(rest.x, rest.y * openness, rest.z)
