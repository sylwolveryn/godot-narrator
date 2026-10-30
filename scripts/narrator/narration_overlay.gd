class_name NarrationOverlay
extends CanvasLayer
## Presents narration on the overlay layer (above the ASCII shader, decision-001). The line
## morphs in: a scrambling front of random glyphs sweeps across it and leaves the real text
## behind; it morphs out by dissolving character by character. Pure presentation: it listens to
## the Narrator and never writes data.

@export var narrator: Narrator
@export var config: NarratorConfig
@export var display_config: DisplayConfig

var _label: Label
var _settings: LabelSettings
var _rng := RandomNumberGenerator.new()
var _text: String = ""
## Per character: 0..1 position in the dissolve order (random), so characters vanish unevenly.
var _dissolve_order: PackedFloat32Array = PackedFloat32Array()
var _morph_in: float = 0.0
var _morph_out: float = 0.0
var _morphing_out: bool = false
var _reroll_in: float = 0.0
var _glyphs: PackedStringArray = PackedStringArray()
var _tween: Tween


func _ready() -> void:
	if config == null:
		config = NarratorConfig.new()
	if display_config == null:
		display_config = DisplayConfig.new()
	_rng.randomize()
	_settings = LabelSettings.new()
	var font := SystemFont.new()
	font.font_names = config.font_names
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_settings.font = font
	_settings.font_color = config.text_color
	_settings.outline_color = config.outline_color
	_label = Label.new()
	_label.name = "NarrationText"
	_label.label_settings = _settings
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.set_anchor(SIDE_LEFT, 0.5)
	_label.set_anchor(SIDE_RIGHT, 0.5)
	_label.set_anchor(SIDE_TOP, config.vertical_anchor)
	_label.set_anchor(SIDE_BOTTOM, config.vertical_anchor)
	_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_label.visible = false
	add_child(_label)
	for i in config.scramble_glyphs.length():
		_glyphs.append(config.scramble_glyphs[i])
	get_viewport().size_changed.connect(_apply_scale)
	_apply_scale()
	if narrator != null:
		narrator.beat_started.connect(show_beat)
		narrator.beat_dissolving.connect(dissolve)


## Re-derives font, outline and text width from the window size.
func _apply_scale() -> void:
	var factor: float = display_config.scale_for(get_viewport())
	_settings.font_size = DisplayConfig.px(config.font_size, factor)
	_settings.outline_size = DisplayConfig.px(config.outline_size, factor, 0)
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var half_width: float = minf(viewport_width * (1.0 - 2.0 * config.side_margin), config.max_text_width * factor) * 0.5
	_label.offset_left = -half_width
	_label.offset_right = half_width


func _process(delta: float) -> void:
	if not _label.visible:
		return
	_reroll_in -= delta
	var reroll: bool = _reroll_in <= 0.0
	if reroll:
		_reroll_in = 1.0 / maxf(config.scramble_rate, 0.001)
	if _morphing_out or _morph_in < 1.0 or reroll:
		_label.text = _compose()


## True while a line is on screen (morphing or resolved).
func is_showing() -> bool:
	return _label != null and _label.visible


## Starts morphing a beat in. Any previous line is replaced.
func show_beat(beat: NarrationBeat) -> void:
	if _tween != null:
		_tween.kill()
	_text = beat.text
	_dissolve_order = PackedFloat32Array()
	for i in _text.length():
		_dissolve_order.append(_rng.randf())
	_morph_in = 0.0
	_morph_out = 0.0
	_morphing_out = false
	_label.modulate = Color.WHITE
	_label.visible = true
	_label.text = _compose()
	_tween = create_tween()
	_tween.tween_method(_set_morph_in, 0.0, 1.0, config.morph_in_seconds)


## Dissolves the current line away (`fast` for a preempting death beat).
func dissolve(fast: bool) -> void:
	if not _label.visible:
		return
	if _tween != null:
		_tween.kill()
	_morphing_out = true
	_morph_in = 1.0
	_morph_out = 0.0
	var duration: float = config.preempt_dissolve_seconds if fast else config.morph_out_seconds
	_tween = create_tween()
	_tween.tween_method(_set_morph_out, 0.0, 1.0, duration)
	_tween.tween_callback(_hide)


func _set_morph_in(value: float) -> void:
	_morph_in = value


func _set_morph_out(value: float) -> void:
	_morph_out = value


func _hide() -> void:
	_label.visible = false
	_morphing_out = false


## The line as it looks right now. Spaces never scramble, so word shapes stay put.
func _compose() -> String:
	var length: int = _text.length()
	var front: float = config.morph_front_chars
	var reach: float = _morph_in * (float(length) + front)
	var out := ""
	for i in length:
		var ch: String = _text[i]
		if ch == " ":
			out += ch
			continue
		if _morphing_out and _dissolve_order[i] < _morph_out:
			out += " "
		elif _morphing_out and _dissolve_order[i] < _morph_out + 0.25:
			out += _random_glyph()
		elif float(i) > reach:
			out += " "
		elif float(i) > reach - front:
			out += _random_glyph()
		else:
			out += ch
	return out


func _random_glyph() -> String:
	if _glyphs.is_empty():
		return "#"
	return _glyphs[_rng.randi() % _glyphs.size()]
