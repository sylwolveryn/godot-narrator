class_name IntroSequence
extends CanvasLayer
## Black screen + abstract wave on the overlay layer (above the ASCII post-process, so the
## wave is crisp and the world underneath is hidden by the veil). It ignores all input.
## When the wave has played it emits SignalBus.intro_finished (RunManager starts the run),
## then dissolves the veil to reveal the world and the spawned player.

@export var config: IntroConfig
@export var display_config: DisplayConfig

@onready var _veil: ColorRect = $Veil

var _material: ShaderMaterial
var _time: float = 0.0
var _tween: Tween


func _ready() -> void:
	if config == null:
		config = IntroConfig.new()
	if display_config == null:
		display_config = DisplayConfig.new()
	_material = _veil.material as ShaderMaterial
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_config()
	get_viewport().size_changed.connect(_apply_cell_size)
	SignalBus.intro_requested.connect(play)
	play(false)


func _process(delta: float) -> void:
	_time += delta
	_material.set_shader_parameter("time", _time)


## Plays the intro. `lite` shortens every timing (restart re-entry).
func play(lite: bool = false) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var time_scale: float = config.restart_time_scale if lite else 1.0
	_set_veil(1.0)
	_set_envelope(0.0)
	_veil.visible = true
	_tween = create_tween()
	_tween.tween_interval(config.black_hold * time_scale)
	_tween.tween_method(_set_envelope, 0.0, 1.0, config.wave_fade_in * time_scale)
	_tween.tween_interval(config.wave_hold * time_scale)
	_tween.tween_callback(_hand_off)
	_tween.set_parallel(true)
	_tween.tween_method(_set_envelope, 1.0, 0.0, config.reveal_duration * time_scale)
	_tween.tween_method(_set_veil, 1.0, 0.0, config.reveal_duration * time_scale)
	_tween.set_parallel(false)
	_tween.tween_callback(func() -> void: _veil.visible = false)


func _hand_off() -> void:
	SignalBus.intro_finished.emit()


func _set_veil(value: float) -> void:
	_material.set_shader_parameter("veil", value)


func _set_envelope(value: float) -> void:
	_material.set_shader_parameter("envelope", value)


func _apply_config() -> void:
	_material.set_shader_parameter("wave_color", config.wave_color)
	_material.set_shader_parameter("line_count", config.line_count)
	_material.set_shader_parameter("frequency", config.frequency)
	_material.set_shader_parameter("speed", config.speed)
	_material.set_shader_parameter("amplitude", config.amplitude)
	_material.set_shader_parameter("line_spacing", config.line_spacing)
	_material.set_shader_parameter("thickness", config.thickness)
	_apply_cell_size()


## The halftone cell grid scales with the window height; everything else in the wave is
## already a fraction of the screen.
func _apply_cell_size() -> void:
	var factor: float = display_config.scale_for(get_viewport())
	var cell := Vector2(DisplayConfig.px(config.cell_size.x, factor), DisplayConfig.px(config.cell_size.y, factor))
	_material.set_shader_parameter("cell_px", cell)
