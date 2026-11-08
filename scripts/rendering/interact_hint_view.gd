class_name InteractHintView
extends Node3D
## The interact hint (task-072): one small billboard glyph floating over the player, leaning a little toward the
## interactable, while one is in reach (SignalBus.interact_focus_changed). Brighter while the interact is held.
## Presentation only; processing runs only while the hint shows.

@export var config: InteractConfig
@export var player: Node3D

var _label: Label3D
var _target: Vector3 = Vector3.ZERO
var _clock: float = 0.0
var _holding: bool = false


func _ready() -> void:
	if config == null:
		config = InteractConfig.new()
	var font := SystemFont.new()
	font.font_names = config.hint_font_names
	_label = Label3D.new()
	_label.name = "Hint"
	_label.font = font
	_label.font_size = config.hint_font_size
	_label.text = config.hint_text
	_label.pixel_size = config.hint_height / maxf(font.get_height(config.hint_font_size), 1.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.outline_size = config.hint_outline_size
	_label.outline_modulate = config.hint_outline_color
	_label.render_priority = 3
	_label.outline_render_priority = 2
	_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_label)
	_label.visible = false
	set_process(false)
	SignalBus.interact_focus_changed.connect(_on_focus_changed)
	SignalBus.interact_hold_changed.connect(func(holding: bool) -> void: _holding = holding)


## True while the hint shows (tests).
func is_showing() -> bool:
	return _label.visible


func _on_focus_changed(available: bool, centre: Vector3) -> void:
	_target = centre
	_label.visible = available and player != null
	set_process(_label.visible)
	if _label.visible:
		_process(0.0)


func _process(delta: float) -> void:
	_clock += delta
	var p: Vector3 = player.global_position
	var lean: Vector3 = (Vector3(_target.x, 0.0, _target.z) - Vector3(p.x, 0.0, p.z)) * config.hint_lean
	_label.global_position = Vector3(p.x, config.hint_lift, p.z) + lean
	var pulse: float = 0.5 + 0.5 * sin(_clock * TAU * config.hint_pulse_hz)
	var c: Color = config.hint_color
	c.a = 1.0 if _holding else lerpf(config.hint_pulse_min, 1.0, pulse)
	_label.modulate = c
