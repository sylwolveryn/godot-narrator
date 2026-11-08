class_name IntroSequence
extends CanvasLayer
## Black screen + abstract wave on the overlay layer (above the ASCII post-process, so the
## wave is crisp and the world underneath is hidden by the veil). Every play picks a random wave
## colour (IntroConfig), and the wave lines glow.
## When the wave has played it emits SignalBus.intro_finished (RunManager starts the run),
## then dissolves the veil to reveal the world and the spawned player.
## Skipping (task-050): while the intro is up, the IntroConfig.skip_action (Esc, Space, mouse
## click, gamepad A/Start) is swallowed â€” it never reaches the menu, the input discovery or the
## player â€” and skips: the hand-off happens at once if it has not yet, then the veil dissolves
## over skip_dissolve_seconds. Every other input is still ignored.

@export var config: IntroConfig
@export var display_config: DisplayConfig

@onready var _veil: ColorRect = $Veil

var _material: ShaderMaterial
var _time: float = 0.0
var _tween: Tween
## True from play() until the veil is gone: the skip action is captured meanwhile.
var _active: bool = false
var _handed_off: bool = false
var _skipping: bool = false
var _veil_value: float = 1.0
var _envelope_value: float = 0.0
var _rng := RandomNumberGenerator.new()
## The wave colour of the current (or last) play.
var wave_color: Color = Color.WHITE


func _ready() -> void:
	if config == null:
		config = IntroConfig.new()
	if display_config == null:
		display_config = DisplayConfig.new()
	_rng.randomize()
	_material = _veil.material as ShaderMaterial
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_config()
	get_viewport().size_changed.connect(_apply_cell_size)
	SignalBus.intro_requested.connect(play)
	play(false)


func _process(delta: float) -> void:
	if not _veil.visible:
		return
	_time += delta
	_material.set_shader_parameter("time", _time)


## Captures the skip action while the intro is up, before the menu, the input discovery or the
## player see it (this node is later in the tree, so its _input runs first).
func _input(event: InputEvent) -> void:
	if not _active or not InputMap.has_action(config.skip_action) or not event.is_action(config.skip_action):
		return
	get_viewport().set_input_as_handled()
	# Also drop the held state of every action this event drives (e.g. move_pointer for a left
	# click, camera_drag for a right click), so holding the skip button does not act afterwards.
	for action: StringName in InputMap.get_actions():
		if action != config.skip_action and InputMap.event_is_action(event, action):
			Input.action_release(action)
	if event.is_pressed() and not event.is_echo():
		skip()


## Plays the intro. `lite` shortens every timing (restart re-entry).
func play(lite: bool = false) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_active = true
	_handed_off = false
	_skipping = false
	_pick_color()
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
	# The wave thins out first (it is gone before the veil is), the veil then lifts on a smooth ease so the world's own
	# reveal disc (already growing from the hand-off) takes over without a visible step.
	_tween.tween_method(_set_envelope, 1.0, 0.0, config.reveal_duration * config.wave_dissolve_fraction * time_scale) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_set_veil, 1.0, 0.0, config.reveal_duration * time_scale) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.set_parallel(false)
	_tween.tween_callback(_finish)


## Jumps to the end of the intro: hands off at once (the world is built in _ready, so the run
## can start immediately) and dissolves the veil quickly from wherever it is. No-op when the
## intro is not up or already skipping.
func skip() -> void:
	if not _active or _skipping:
		return
	_skipping = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not _handed_off:
		_hand_off()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_method(_set_envelope, _envelope_value, 0.0, config.skip_dissolve_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_veil, _veil_value, 0.0, config.skip_dissolve_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.set_parallel(false)
	_tween.tween_callback(_finish)


## True while the intro covers the screen (and captures the skip action).
func is_active() -> bool:
	return _active


func _hand_off() -> void:
	_handed_off = true
	SignalBus.intro_finished.emit()


func _finish() -> void:
	_active = false
	_skipping = false
	_veil.visible = false


func _pick_color() -> void:
	if config.random_color:
		var hue: float = fposmod(_rng.randf_range(config.hue_range.x, config.hue_range.y), 1.0)
		var sat: float = _rng.randf_range(config.saturation_range.x, config.saturation_range.y)
		var val: float = _rng.randf_range(config.value_range.x, config.value_range.y)
		wave_color = Color.from_hsv(hue, sat, val)
	else:
		wave_color = config.wave_color
	_material.set_shader_parameter("wave_color", wave_color)


func _set_veil(value: float) -> void:
	_veil_value = value
	_material.set_shader_parameter("veil", value)


func _set_envelope(value: float) -> void:
	_envelope_value = value
	_material.set_shader_parameter("envelope", value)


func _apply_config() -> void:
	_material.set_shader_parameter("line_count", config.line_count)
	_material.set_shader_parameter("frequency", config.frequency)
	_material.set_shader_parameter("speed", config.speed)
	_material.set_shader_parameter("amplitude", config.amplitude)
	_material.set_shader_parameter("line_spacing", config.line_spacing)
	_material.set_shader_parameter("thickness", config.thickness)
	_material.set_shader_parameter("glow_strength", config.glow_strength)
	_material.set_shader_parameter("glow_width", config.glow_width)
	_apply_cell_size()


## The halftone cell grid scales with the window height; everything else in the wave is
## already a fraction of the screen.
func _apply_cell_size() -> void:
	var factor: float = display_config.scale_for(get_viewport())
	var cell := Vector2(DisplayConfig.px(config.cell_size.x, factor), DisplayConfig.px(config.cell_size.y, factor))
	_material.set_shader_parameter("cell_px", cell)
