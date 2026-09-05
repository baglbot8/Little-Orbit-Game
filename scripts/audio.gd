class_name OrbitAudio
extends Node
## Soft, asset-free PCM music and interaction sounds. All synthesis is cached
## at startup; playback allocates no sample buffers. Volume controls use linear
## gain (0 = silent, 1 = full scale) and leave the shared Master bus alone.

const SAMPLE_RATE: int = 22050
const LOOP_SECONDS: float = 48.0
const VOICE_COUNT: int = 6

const SYLLABLE_VARIANTS := 6

var _dialogue: AudioStreamPlayer
var _syllables: Array[AudioStreamWAV] = []
var _voice_gate_until := 0
var _audio_started := false
var _ambient: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _cues: Dictionary = {}
var _last_played: Dictionary = {}
var _music_volume: float = 0.18
var _effects_volume: float = 0.24
var _stopped: bool = false


func _ready() -> void:
	if _stopped or is_instance_valid(_ambient):
		return
	_build_cues()
	_build_syllables()
	_dialogue = AudioStreamPlayer.new()
	_dialogue.name = "DialogueVoice"
	_dialogue.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_dialogue.volume_db = linear_to_db(_effects_volume)
	_dialogue.finished.connect(_release_voice.bind(_dialogue))
	add_child(_dialogue)
	for i in range(VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		voice.name = "CueVoice%d" % i
		voice.volume_db = linear_to_db(_effects_volume)
		voice.finished.connect(_release_voice.bind(voice))
		add_child(voice)
		_voices.append(voice)
	_ambient = AudioStreamPlayer.new()
	_ambient.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_ambient.name = "GentleOrbit"
	_ambient.volume_db = linear_to_db(_music_volume)
	_ambient.stream = _build_ambient()
	add_child(_ambient)
	if not OS.has_feature("web"):
		resume_on_user_gesture()


## Call synchronously from a click/tap/key handler (Start/Continue also works).
## Godot's Web driver resumes its own AudioContext on browser input; do not
## create a second JS context or reach into private export-template internals.
func resume_on_user_gesture() -> void:
	if _stopped or not is_inside_tree():
		return
	_audio_started = true
	if is_instance_valid(_ambient) and not _ambient.playing:
		_ambient.play()


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch
			or event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		resume_on_user_gesture()


## character_index is the revealed text offset, NOT the speaker ID.
## HUD should emit only for newly revealed non-whitespace characters.
func play_voice(speaker_id: int, character_index: int) -> void:
	if _stopped or not _audio_started or not is_inside_tree() or not is_instance_valid(_dialogue):
		return
	if _effects_volume <= 0.0 or AudioServer.is_bus_mute(0):
		stop_voice()
		return
	if speaker_id < 0 or speaker_id > 3 or character_index < 0:
		return
	var now := Time.get_ticks_msec()
	if now < _voice_gate_until or _dialogue.playing:
		return
	var variant := (character_index * 5 + character_index / 3) % SYLLABLE_VARIANTS
	_dialogue.stream = _syllables[speaker_id * SYLLABLE_VARIANTS + variant]
	_dialogue.play()
	_voice_gate_until = now + 95


func stop_voice() -> void:
	if is_instance_valid(_dialogue):
		_dialogue.stop()
		_dialogue.stream = null
	_voice_gate_until = 0


func _build_syllables() -> void:
	if not _syllables.is_empty():
		return
	# Lumi: airy upward vowels; Bolt: paired electronic notes;
	# Pip: warm voiced chirps; Miso: low, rounded bubbling vowels.
	for speaker in range(4):
		for variant in range(SYLLABLE_VARIANTS):
			var duration: float = [0.090, 0.070, 0.080, 0.100][speaker]
			var base: float = [370.0, 235.0, 290.0, 165.0][speaker]
			var frequency := base * pow(2.0, float([0, 4, 7, 2, 9, 5][variant]) / 12.0)
			var samples := _silence(duration + 0.008)
			match speaker:
				0:
					_add_tone(samples, 0, duration, frequency, 0.43, 0.012, 0.12, 0.5, frequency * 1.18)
					_add_tone(samples, 0, duration, frequency * 3, 0.045, 0.015)
				1:
					_add_tone(samples, 0, 0.035, frequency, 0.40, 0.005, 0.32)
					_add_tone(samples, 0.032, 0.038, frequency * 1.5, 0.34, 0.005, 0.24)
				2:
					_add_tone(samples, 0, duration, frequency, 0.44, 0.008, 0.38, 0.4, frequency * 0.88)
					_add_tone(samples, 0, duration, frequency * 3, 0.06, 0.010)
				3:
					_add_tone(samples, 0, duration, frequency, 0.49, 0.014, 0.24, 0.2, frequency * 1.30)
					_add_tone(samples, 0.027, 0.060, frequency * 2, 0.09, 0.012, 0, 0, frequency * 1.6)
			_syllables.append(_wav(samples))


func play_cue(kind: String) -> void:
	if _stopped or _effects_volume <= 0.0 or not _cues.has(kind) or not is_inside_tree():
		return
	var now := Time.get_ticks_msec()
	var cooldown: int = 230 if kind == "step" else 100
	if now - int(_last_played.get(kind, -10000)) < cooldown:
		return
	# Keep existing tails intact; drop excess triggers instead of stealing voices.
	for voice in _voices:
		if not voice.playing:
			_last_played[kind] = now
			voice.stream = _cues[kind]
			voice.play()
			return


func set_music_volume(value: float) -> void:
	if is_nan(value):
		return
	_music_volume = clampf(value, 0.0, 1.0)
	if is_instance_valid(_ambient):
		_ambient.volume_db = linear_to_db(_music_volume)


func set_effects_volume(value: float) -> void:
	if is_nan(value):
		return
	_effects_volume = clampf(value, 0.0, 1.0)
	if is_instance_valid(_dialogue):
		_dialogue.volume_db = linear_to_db(_effects_volume)
	if _effects_volume <= 0.0:
		stop_voice()
	for voice in _voices:
		if is_instance_valid(voice):
			voice.volume_db = linear_to_db(_effects_volume)


## Terminal, idempotent shutdown; create a new OrbitAudio to start again.
## Call before quitting when possible. Godot 4.7.1 releases stopped playbacks
## on a later audio mix step, so immediate engine exit can still report its
## pending WAV/playback references even after all our references are released.
func stop_all() -> void:
	_stopped = true
	_audio_started = false
	stop_voice()
	_syllables.clear()
	if is_instance_valid(_ambient):
		_ambient.stop()
		_ambient.stream = null
	for voice in _voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	_cues.clear()
	_last_played.clear()


func _release_voice(voice: AudioStreamPlayer) -> void:
	# The cache owns reusable PCM; idle players need not retain a stream.
	if is_instance_valid(voice) and not voice.playing:
		voice.stream = null


func _build_cues() -> void:
	var samples := _silence(0.19)
	_add_tone(samples, 0.0, 0.18, 130.81, 0.16, 0.018, 0.0, 0.0, 98.0)
	_cues["step"] = _wav(samples)

	samples = _silence(0.65)
	_add_tone(samples, 0.0, 0.62, 261.63, 0.23, 0.035, 0.07, 2.8, 523.25)
	_cues["jump"] = _wav(samples)

	# Short, distinct phrases keep interaction feedback clear over the music.
	samples = _silence(0.85)
	for i in range(3):
		_add_tone(samples, i * 0.10, 0.62, _hz([72, 76, 79][i]), 0.20, 0.012, 0.09, 2.5)
	_cues["collect"] = _wav(samples)

	samples = _silence(4.8)
	for i in range(4):
		_add_tone(samples, i * 0.48, 3.2, _hz([48, 55, 60, 64][i]), 0.14, 0.45, 0.06, 0.8)
	_cues["travel"] = _wav(samples)

	samples = _silence(0.65)
	_add_tone(samples, 0.0, 0.52, _hz(60), 0.23, 0.014, 0.07, 2.5)
	_add_tone(samples, 0.09, 0.52, _hz(67), 0.16, 0.018, 0.07, 2.5)
	_cues["place"] = _wav(samples)

	samples = _silence(0.42)
	_add_tone(samples, 0.0, 0.30, _hz(67), 0.17, 0.012, 0.04, 2.0)
	_add_tone(samples, 0.10, 0.30, _hz(72), 0.13, 0.016, 0.04, 2.0)
	_cues["dialog"] = _wav(samples)


func _build_ambient() -> AudioStreamWAV:
	var samples := _silence(LOOP_SECONDS)
	# C major pentatonic, 60 BPM. Empty beats let the soft bell tails breathe.
	var melody: Array[int] = [72, -1, 76, -1, 79, -1, -1, 76,
		74, -1, -1, 69, -1, 72, -1, -1,
		67, -1, 72, -1, 76, -1, -1, -1]
	for beat in range(melody.size()):
		if melody[beat] >= 0:
			_add_tone(samples, float(beat) * 2.0, 3.8, _hz(melody[beat]), 0.17, 0.09, 0.10, 2.4)
	# Sparse low fifths; all envelopes finish before the loop boundary.
	for bar in range(4):
		var root: int = [48, 45, 43, 48][bar]
		_add_tone(samples, bar * 12.0, 10.5, _hz(root), 0.12, 1.6, 0.025, 0.0)
		_add_tone(samples, bar * 12.0, 10.5, _hz(root + 7), 0.07, 1.8, 0.02, 0.0)
	# Silence at both ends makes the rest across the seam click-free.
	return _wav(samples, true)


func _silence(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(ceil(seconds * SAMPLE_RATE)))
	samples.fill(0.0)
	return samples


func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, float(midi - 69) / 12.0)


func _add_tone(samples: PackedFloat32Array, start: float, duration: float,
		frequency: float, gain: float, attack: float, overtone: float = 0.0,
		decay: float = 0.0, end_frequency: float = -1.0) -> void:
	var offset := int(start * SAMPLE_RATE)
	var count := mini(int(duration * SAMPLE_RATE), samples.size() - offset)
	var target := frequency if end_frequency <= 0.0 else end_frequency
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / maxf(1.0, float(count - 1))
		var fade_in := clampf(t / attack, 0.0, 1.0)
		fade_in = fade_in * fade_in * (3.0 - 2.0 * fade_in)
		var fade_out := 0.5 + 0.5 * cos(PI * progress)
		var envelope := fade_in * fade_out * exp(-decay * progress)
		# Integrate the pitch ramp to preserve phase continuity during glides.
		var phase := TAU * (frequency * t + (target - frequency) * t * t / (2.0 * duration))
		var tone := sin(phase) + overtone * sin(phase * 2.0) * exp(-3.0 * progress)
		samples[offset + i] += gain * envelope * tone


func _wav(samples: PackedFloat32Array, looping: bool = false) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i in range(samples.size()):
		var signed_sample := int(round(clampf(samples[i], -0.95, 0.95) * 32767.0))
		pcm.encode_s16(i * 2, signed_sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


func _exit_tree() -> void:
	stop_all()
	_voices.clear()
	_ambient = null
	_dialogue = null
