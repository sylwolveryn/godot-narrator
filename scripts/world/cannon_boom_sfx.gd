class_name CannonBoomSfx
extends Node
## The boom of a cannon shot (task-073). Presentation: listens to SignalBus.cannon_fired. Plays CannonConfig.boom_file
## when it exists (override folder first, then the game folder, then res://, through NarrationLibrary.resolve_file),
## else a boom synthesized once at start: a low sine thump sweeping down with a fast decay plus a short low-passed noise
## crack. Random pitch per shot; booms closer than boom_min_interval are skipped (autofire at 5/s still booms each).
## The impact of a ball on a destructible reuses the dirt crunch (DirtCrunchSfx listens to destructible_destroyed).

const POLYPHONY: int = 4

@export var config: CannonConfig
## Optional: where the override file is looked up. Without it only the synthesized boom plays.
@export var library: NarrationLibrary

var _player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _last_ms: int = -1000000
## Booms played (tests) and whether the sound comes from a file.
var played: int = 0
var from_file: bool = false


func _ready() -> void:
	if config == null:
		config = CannonConfig.new()
	_rng.randomize()
	_player = AudioStreamPlayer.new()
	_player.name = "Boom"
	_player.bus = config.boom_bus
	_player.max_polyphony = POLYPHONY
	_player.volume_db = config.boom_volume_db
	add_child(_player)
	if library != null:
		var path: String = library.resolve_file(config.boom_file)
		_player.stream = library.load_audio(path) if path != "" else null
	from_file = _player.stream != null
	if _player.stream == null:
		_player.stream = synthesize()
	SignalBus.cannon_fired.connect(func(_i: int, _m: Vector3, _d: Vector3) -> void: boom())


## Plays one boom unless one played less than boom_min_interval ago. Returns true when it played.
func boom() -> bool:
	var now: int = Time.get_ticks_msec()
	if float(now - _last_ms) < config.boom_min_interval * 1000.0:
		return false
	_last_ms = now
	_player.pitch_scale = 1.0 + _rng.randf_range(-config.boom_pitch_jitter, config.boom_pitch_jitter)
	_player.play()
	played += 1
	return true


func stream() -> AudioStream:
	return _player.stream


## Renders the boom: thump (exponential frequency sweep, exponential decay) + noise crack, soft-clipped.
func synthesize() -> AudioStreamWAV:
	var rate: int = config.boom_sample_rate
	var count: int = maxi(1, roundi(config.boom_duration * rate))
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase: float = 0.0
	var smooth: float = 0.0
	var decay: float = maxf(config.boom_decay, 0.001)
	var noise_len: float = maxf(config.boom_noise_seconds, 0.001)
	for i in count:
		var t: float = float(i) / rate
		var u: float = t / config.boom_duration
		var freq: float = config.boom_freq_start * pow(config.boom_freq_end / config.boom_freq_start, u)
		phase += TAU * freq / rate
		var thump: float = sin(phase) * exp(-t / decay)
		var noise: float = _rng.randf_range(-1.0, 1.0) * exp(-t / noise_len)
		smooth = lerpf(noise, smooth, config.boom_lowpass)
		var s: float = thump * (1.0 - config.boom_noise_share) + smooth * config.boom_noise_share * 2.0
		var tail: float = 1.0 - u
		data.encode_s16(i * 2, roundi(tanh(s * 1.6) * tail * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
