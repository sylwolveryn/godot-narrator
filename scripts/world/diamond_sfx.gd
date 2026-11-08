class_name DiamondSfx
extends Node
## The diamond pickup sound (task-076). Presentation: listens to SignalBus.diamond_collected. Plays
## RemainsConfig.pickup_file when it exists (override folder, game folder, res://, through NarrationLibrary.resolve_file),
## else a "ting" synthesized once at start: two sine partials gliding up, decaying fast. Slightly random pitch per pickup.

const POLYPHONY: int = 4

@export var config: RemainsConfig
## Optional: where the override file is looked up. Without it only the synthesized sound plays.
@export var library: NarrationLibrary

var _player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
## Pickups played (tests).
var played: int = 0


func _ready() -> void:
	if config == null:
		config = RemainsConfig.new()
	_rng.randomize()
	_player = AudioStreamPlayer.new()
	_player.name = "Ting"
	_player.bus = config.pickup_bus
	_player.max_polyphony = POLYPHONY
	_player.volume_db = config.pickup_volume_db
	add_child(_player)
	if library != null:
		var path: String = library.resolve_file(config.pickup_file)
		_player.stream = library.load_audio(path) if path != "" else null
	if _player.stream == null:
		_player.stream = synthesize()
	SignalBus.diamond_collected.connect(func(_c: Vector2i, _t: int) -> void: ting())


func ting() -> void:
	_player.pitch_scale = 1.0 + _rng.randf_range(-config.pickup_pitch_jitter, config.pickup_pitch_jitter)
	_player.play()
	played += 1


func stream() -> AudioStream:
	return _player.stream


func synthesize() -> AudioStreamWAV:
	var rate: int = config.pickup_sample_rate
	var count: int = maxi(1, roundi(config.pickup_duration * rate))
	var data := PackedByteArray()
	data.resize(count * 2)
	var p1: float = 0.0
	var p2: float = 0.0
	var decay: float = maxf(config.pickup_decay, 0.0001)
	for i in count:
		var t: float = float(i) / float(rate)
		var glide: float = lerpf(1.0, config.pickup_glide, minf(t / maxf(config.pickup_duration * 0.3, 0.0001), 1.0))
		p1 += TAU * config.pickup_freq * glide / rate
		p2 += TAU * config.pickup_freq_2 * glide / rate
		var env: float = exp(-t / decay) * (1.0 - float(i) / float(count))
		var s: float = (sin(p1) * 0.6 + sin(p2) * 0.4 * exp(-t / (decay * 0.5))) * env
		data.encode_s16(i * 2, roundi(clampf(s, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
