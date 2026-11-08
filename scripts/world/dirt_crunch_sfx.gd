class_name DirtCrunchSfx
extends Node
## The crunch of a destroyed dirt cell (task-070). Presentation: listens to SignalBus.dirt_destroyed. Plays
## DirtConfig.crunch_file when it exists (override folder first, then the game folder, then res://, through
## NarrationLibrary.resolve_file), else a crunch synthesized once at start: a few short decaying grains of low-passed noise.
## Every crunch gets a slightly random pitch; crunches closer than crunch_min_interval are skipped.

## Simultaneous crunches the player can mix.
const POLYPHONY: int = 3

@export var config: DirtConfig
## Optional: where the override file is looked up. Without it only the synthesized crunch plays.
@export var library: NarrationLibrary

var _player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _last_ms: int = -1000000
## Crunches played (tests).
var played: int = 0
## True when the sound comes from a file (tests).
var from_file: bool = false


func _ready() -> void:
	if config == null:
		config = DirtConfig.new()
	_rng.randomize()
	_player = AudioStreamPlayer.new()
	_player.name = "Crunch"
	_player.bus = config.crunch_bus
	_player.max_polyphony = POLYPHONY
	_player.volume_db = config.crunch_volume_db
	add_child(_player)
	_player.stream = _file_stream()
	from_file = _player.stream != null
	if _player.stream == null:
		_player.stream = synthesize()
	SignalBus.dirt_destroyed.connect(func(_m: StringName, _c: Vector2i, _cause: StringName) -> void: crunch())


## Plays one crunch unless one played less than crunch_min_interval ago. Returns true when it played.
func crunch() -> bool:
	var now: int = Time.get_ticks_msec()
	if float(now - _last_ms) < config.crunch_min_interval * 1000.0:
		return false
	_last_ms = now
	_player.pitch_scale = 1.0 + _rng.randf_range(-config.crunch_pitch_jitter, config.crunch_pitch_jitter)
	_player.play()
	played += 1
	return true


## The current stream (tests).
func stream() -> AudioStream:
	return _player.stream


## Renders the crunch: grains of noise at random times in the first half, each decaying fast, low-passed, faded out.
func synthesize() -> AudioStreamWAV:
	var rate: int = config.crunch_sample_rate
	var count: int = maxi(1, roundi(config.crunch_duration * rate))
	var starts := PackedInt32Array()
	for i in maxi(config.crunch_grains, 1):
		starts.append(_rng.randi_range(0, count / 2))
	starts.sort()
	var data := PackedByteArray()
	data.resize(count * 2)
	var smooth: float = 0.0
	var decay: float = maxf(config.crunch_grain_decay, 0.0001) * rate
	for i in count:
		var amp: float = 0.0
		for s in starts:
			if i >= s:
				amp += exp(-float(i - s) / decay)
		var noise: float = _rng.randf_range(-1.0, 1.0) * minf(amp, 1.0)
		smooth = lerpf(noise, smooth, config.crunch_lowpass)
		var tail: float = 1.0 - float(i) / float(count)
		data.encode_s16(i * 2, roundi(clampf(smooth * tail, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


func _file_stream() -> AudioStream:
	if library == null:
		return null
	var path: String = library.resolve_file(config.crunch_file)
	return library.load_audio(path) if path != "" else null
