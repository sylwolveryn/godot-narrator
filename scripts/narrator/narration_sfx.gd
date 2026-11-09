class_name NarrationSfx
extends Node
## Plays a soft ambient sound with each beat. No audio assets exist, so every mood is
## synthesised once from its NarrationMood recipe into an AudioStreamWAV and cached.

@export var narrator: Narrator
@export var config: NarratorConfig

## Volume of narration voice files (NarrationLibraryConfig.voice_volume_db, set by the main scene builder).
@export var voice_volume_db: float = -4.0

var _player: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _streams: Dictionary[StringName, AudioStreamWAV] = {}
var _volumes: Dictionary[StringName, float] = {}
var _rng := RandomNumberGenerator.new()

## Group the debug overlay finds the sfx player by.
const GROUP := &"narration_sfx"


func _ready() -> void:
	if config == null:
		config = NarratorConfig.new()
	_rng.seed = 1
	add_to_group(GROUP)
	_player = AudioStreamPlayer.new()
	_player.name = "Player"
	_player.bus = config.sfx_bus
	add_child(_player)
	_voice = AudioStreamPlayer.new()
	_voice.name = "Voice"
	_voice.bus = config.sfx_bus
	add_child(_voice)
	for mood: NarrationMood in config.moods:
		_streams[mood.id] = synthesize(mood)
		_volumes[mood.id] = mood.volume_db
	if narrator != null:
		narrator.beat_started.connect(_on_beat_started)


## True when a sound exists for this mood.
func has_mood(mood: StringName) -> bool:
	return _streams.has(mood)


## Plays the sound of a mood (replacing whatever is playing).
func play_mood(mood: StringName) -> void:
	if not _streams.has(mood):
		return
	_player.stream = _streams[mood]
	_player.volume_db = config.sfx_volume_db + _volumes[mood]
	_player.play()


## Renders a mood recipe to 16-bit mono PCM.
func synthesize(mood: NarrationMood) -> AudioStreamWAV:
	var rate: int = config.sfx_sample_rate
	var count: int = maxi(1, roundi(mood.duration * rate))
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase: float = 0.0
	var over_phase: float = 0.0
	var held_noise: float = 0.0
	for i in count:
		var t: float = float(i) / float(rate)
		var progress: float = float(i) / float(count)
		var freq: float = lerpf(mood.freq_start, mood.freq_end, progress)
		phase += TAU * freq / float(rate)
		over_phase += TAU * freq * mood.overtone_ratio / float(rate)
		if mood.crackle <= 0.0 or _rng.randf() > mood.crackle:
			held_noise = _rng.randf_range(-1.0, 1.0)
		var tone: float = sin(phase) + sin(over_phase) * mood.overtone_level
		var sample: float = tone * mood.tone_level / (1.0 + mood.overtone_level) + held_noise * mood.noise_level
		sample *= _envelope(t, mood.duration, mood.attack, mood.release) * _gate(t, mood)
		data.encode_s16(i * 2, roundi(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


func _envelope(t: float, duration: float, attack: float, release: float) -> float:
	var up: float = clampf(t / maxf(attack, 0.0001), 0.0, 1.0)
	var down: float = clampf((duration - t) / maxf(release, 0.0001), 0.0, 1.0)
	return up * down


## 1 while a beep is sounding (or always, for continuous moods); each beep fades out smoothly.
func _gate(t: float, mood: NarrationMood) -> float:
	if mood.pulse_count <= 0:
		return 1.0
	var index: int = int(t / mood.pulse_interval)
	if index >= mood.pulse_count:
		return 0.0
	var into: float = t - float(index) * mood.pulse_interval
	if into >= mood.pulse_length:
		return 0.0
	return sin(PI * into / mood.pulse_length)


## The mood always plays; a narration voice file (Narrator.current_voice) plays on top of it.
func _on_beat_started(beat: NarrationBeat) -> void:
	play_mood(beat.mood)
	if narrator.current_voice != null:
		_voice.stream = narrator.current_voice
		_voice.volume_db = voice_volume_db
		_voice.play()


## The mood player (read-only, debug overlay).
func mood_player() -> AudioStreamPlayer:
	return _player


## The voice player (read-only, debug overlay).
func voice_player() -> AudioStreamPlayer:
	return _voice
