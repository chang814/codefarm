extends Node
## Small synthesized sound set. Every sound is generated here at startup, so the
## project ships no audio files. Sounds are short and soft; `level` 0 mutes.
const RATE := 22050
const VOICES := 6
const LEVEL_DB := [-80.0, -17.0, -8.0]

var level := 2
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20261114
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_streams = {
		"harvest": _bake(0.17, _harvest),
		"miss": _bake(0.15, _miss),
		"till": _bake(0.16, _till),
		"stuck": _bake(0.14, _stuck),
		"flip": _bake(0.30, _flip),
		"unlock": _bake(0.62, _unlock),
		"deny": _bake(0.22, _deny),
	}


## Plays a named sound. `gap` drops repeats that would pile up, for example a
## fleet of bots harvesting on the same frame.
func play(sound: String, gap: float = 0.045, vary: float = 0.05) -> void:
	if level <= 0 or not _streams.has(sound) or _players.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound, -10.0)) < gap:
		return
	_last_played[sound] = now
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[sound]
	player.volume_db = LEVEL_DB[clampi(level, 0, 2)]
	player.pitch_scale = 1.0 + _rng.randf_range(-vary, vary)
	player.play()


func has_sound(sound: String) -> bool:
	return _streams.has(sound)


func _bake(seconds: float, shape: Callable) -> AudioStreamWAV:
	var count := int(seconds * RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = hash(seconds)
	var smooth := 0.0
	for i in count:
		var t := float(i) / RATE
		# One-pole low-pass keeps the noise airy rather than hissy.
		smooth = lerpf(smooth, noise.randf_range(-1.0, 1.0), 0.35)
		var value: float = shape.call(t, t / seconds, smooth)
		# Two-millisecond edges avoid clicks at either end.
		value *= minf(1.0, t / 0.002) * minf(1.0, (seconds - t) / 0.004)
		bytes.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav


func _tone(t: float, hz: float) -> float:
	return sin(TAU * hz * t)


func _harvest(t: float, u: float, noise: float) -> float:
	var swish := noise * sin(PI * u) * (1.0 - u) * 0.55
	var pluck := (_tone(t, 740.0) + 0.4 * _tone(t, 1480.0)) * exp(-u * 9.0) * 0.30
	return swish + pluck


func _miss(_t: float, u: float, noise: float) -> float:
	return noise * pow(sin(PI * u), 2.0) * 0.38


func _till(t: float, u: float, noise: float) -> float:
	var thud := _tone(t, lerpf(120.0, 62.0, u)) * exp(-u * 5.0) * 0.75
	return thud + noise * exp(-u * 14.0) * 0.30


func _stuck(t: float, u: float, _noise: float) -> float:
	return _tone(t, lerpf(190.0, 120.0, u)) * exp(-u * 6.0) * 0.60


func _flip(t: float, u: float, _noise: float) -> float:
	# Phase is integrated by hand so the upward sweep stays smooth.
	var hz_phase := TAU * (420.0 * t + 0.5 * (520.0 / 0.30) * t * t)
	return sin(hz_phase) * sin(PI * u) * 0.38


func _unlock(t: float, _u: float, _noise: float) -> float:
	var value := 0.0
	var notes := [523.25, 659.25, 783.99]
	for i in notes.size():
		var start := 0.09 * i
		if t >= start:
			var local := t - start
			value += (_tone(local, notes[i]) + 0.25 * _tone(local, notes[i] * 2.0)) * exp(-local * 7.0) * 0.26
	return value


func _deny(t: float, _u: float, _noise: float) -> float:
	var value := 0.0
	for i in 2:
		var start := 0.10 * i
		if t >= start:
			var local := t - start
			value += _tone(local, 233.0 - 25.0 * i) * exp(-local * 22.0) * 0.45
	return value
