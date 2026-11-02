class_name NarrationOverlay
extends CanvasLayer
## Presents narration on the overlay layer (above the world, decision-001). The line is laid out once per beat
## into single letters. They assemble like Spike B's narration moment: every letter flies in from a scattered
## spot with an ease-out, staggered left to right, and settles on its place; the line then rests (no per-frame
## work at all) and finally disperses the same calm way (letters drift up and away, fading). A soft additive glow
## tinted by the beat's mood sits behind the letters and is strongest while they fly. No random character swapping.
## Cost: two canvas items redrawn only while a morph runs (about 3 batched passes: glow quads, outlines, fills),
## nothing allocated per frame. Pure presentation: it listens to the Narrator and never writes data.

enum Phase { IDLE, ASSEMBLE, HOLD, DISPERSE }

@export var narrator: Narrator
@export var config: NarratorConfig
@export var display_config: DisplayConfig

var phase: Phase = Phase.IDLE

var _font: SystemFont
var _font_px: int = 1
var _outline_px: int = 0
var _glow_px: float = 1.0
var _scale: float = 1.0
var _glow_node: Node2D
var _text_node: Node2D
var _glow_texture: GradientTexture2D
var _rng := RandomNumberGenerator.new()
var _text: String = ""
var _glow_color: Color = Color.WHITE
var _t: float = 0.0
var _duration: float = 1.0
## Per character (kept for a resize re-layout): the glyph, its resting position (baseline origin), the offsets it
## flies in from and leaves towards, and its start delay (0..stagger_fraction) in each direction.
var _chars: PackedStringArray = PackedStringArray()
var _rest: PackedVector2Array = PackedVector2Array()
var _in_unit: PackedVector2Array = PackedVector2Array()
var _out_unit: PackedVector2Array = PackedVector2Array()
var _in_delay: PackedFloat32Array = PackedFloat32Array()
var _out_delay: PackedFloat32Array = PackedFloat32Array()
## Per-frame cache of the current position/alpha/glow of each letter (filled by _pose, read by both draw passes).
var _pos: PackedVector2Array = PackedVector2Array()
var _alpha: PackedFloat32Array = PackedFloat32Array()
var _glow: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	if config == null:
		config = NarratorConfig.new()
	if display_config == null:
		display_config = DisplayConfig.new()
	_rng.randomize()
	_font = SystemFont.new()
	_font.font_names = config.font_names
	_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_glow_texture = _make_glow_texture()
	_glow_node = Node2D.new()
	_glow_node.name = "NarrationGlow"
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_node.material = additive
	_glow_node.draw.connect(_draw_glow)
	add_child(_glow_node)
	_text_node = Node2D.new()
	_text_node.name = "NarrationText"
	_text_node.draw.connect(_draw_text)
	add_child(_text_node)
	set_process(false)
	get_viewport().size_changed.connect(_on_resized)
	_apply_scale()
	if narrator != null:
		narrator.beat_started.connect(show_beat)
		narrator.beat_dissolving.connect(dissolve)


func _process(delta: float) -> void:
	advance(delta)


## Moves the morph on by `delta` seconds (tests call it directly).
func advance(delta: float) -> void:
	if phase == Phase.IDLE or phase == Phase.HOLD:
		return
	_t += delta
	if _t >= _duration:
		if phase == Phase.ASSEMBLE:
			phase = Phase.HOLD
			set_process(false)
			_redraw()
		else:
			_clear()
		return
	_redraw()


## True while a line is on screen (assembling, resting or dispersing).
func is_showing() -> bool:
	return phase != Phase.IDLE


## Lays the beat out and starts assembling it. Any previous line is replaced.
func show_beat(beat: NarrationBeat) -> void:
	_text = beat.text
	_glow_color = config.mood_glow_colors.get(beat.mood, config.default_glow_color)
	_layout()
	_fill_motion()
	phase = Phase.ASSEMBLE
	_t = 0.0
	_duration = maxf(config.morph_in_seconds, 0.001)
	set_process(true)
	_redraw()


## Disperses the current line (`fast` for a preempting death beat). A line caught mid-assembly leaves from
## where it is: the dispersal restarts from its resting layout, which is at most one short beat of difference.
func dissolve(fast: bool) -> void:
	if phase == Phase.IDLE:
		return
	phase = Phase.DISPERSE
	_t = 0.0
	_duration = maxf(config.preempt_dissolve_seconds if fast else config.morph_out_seconds, 0.001)
	set_process(true)
	_redraw()


func _clear() -> void:
	phase = Phase.IDLE
	set_process(false)
	_glow_node.queue_redraw()
	_text_node.queue_redraw()


func _redraw() -> void:
	_pose()
	_glow_node.queue_redraw()
	_text_node.queue_redraw()


func _on_resized() -> void:
	_apply_scale()
	if phase == Phase.IDLE:
		return
	_layout()
	_fill_motion()
	_redraw()


func _apply_scale() -> void:
	_scale = display_config.scale_for(get_viewport())
	_font_px = DisplayConfig.px(config.font_size, _scale)
	_outline_px = DisplayConfig.px(config.outline_size, _scale, 0)
	_glow_px = float(_font_px) * config.glow_size_factor


## Greedy word-wrap into centred lines; fills _chars and _rest. Runs once per beat (and on resize).
func _layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var max_width: float = minf(viewport_size.x * (1.0 - 2.0 * config.side_margin), config.max_text_width * _scale)
	var words: PackedStringArray = _text.split(" ", false)
	var space_w: float = _advance(" ")
	var lines: Array[PackedStringArray] = []
	var widths: PackedFloat32Array = PackedFloat32Array()
	var line := PackedStringArray()
	var line_w: float = 0.0
	for word in words:
		var word_w: float = 0.0
		for i in word.length():
			word_w += _advance(word[i])
		if not line.is_empty() and line_w + space_w + word_w > max_width:
			lines.append(line)
			widths.append(line_w)
			line = PackedStringArray()
			line_w = 0.0
		if not line.is_empty():
			line_w += space_w
		line.append(word)
		line_w += word_w
	if not line.is_empty():
		lines.append(line)
		widths.append(line_w)
	var line_h: float = _font.get_height(_font_px)
	var top: float = viewport_size.y * config.vertical_anchor - line_h * lines.size() * 0.5
	_chars.clear()
	_rest.clear()
	for l in lines.size():
		var x: float = (viewport_size.x - widths[l]) * 0.5
		var y: float = top + line_h * l + _font.get_ascent(_font_px)
		for w in lines[l].size():
			if w > 0:
				x += space_w
			var word: String = lines[l][w]
			for i in word.length():
				_chars.append(word[i])
				_rest.append(Vector2(x, y))
				x += _advance(word[i])


func _advance(ch: String) -> float:
	return _font.get_char_size(ch.unicode_at(0), _font_px).x


## Rolls each letter's fly-in/out offsets (unit vectors, scaled when posed) and delays.
func _fill_motion() -> void:
	var n: int = _chars.size()
	_in_unit.resize(n)
	_out_unit.resize(n)
	_in_delay.resize(n)
	_out_delay.resize(n)
	_pos.resize(n)
	_alpha.resize(n)
	_glow.resize(n)
	var denom: float = maxf(float(n - 1), 1.0)
	for i in n:
		_in_unit[i] = Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf())
		_out_unit[i] = Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf())
		_in_delay[i] = config.stagger_fraction * (0.75 * float(i) / denom + 0.25 * _rng.randf())
		_out_delay[i] = config.stagger_fraction * (0.3 * float(i) / denom + 0.7 * _rng.randf())


## Fills the per-letter pose caches for the current phase and time.
func _pose() -> void:
	var u: float = clampf(_t / _duration, 0.0, 1.0)
	var span: float = maxf(1.0 - config.stagger_fraction, 0.001)
	var in_px: float = config.assemble_scatter_px * _scale
	var out_px: float = config.disperse_scatter_px * _scale
	var rise: Vector2 = Vector2(0.0, -config.disperse_rise_px * _scale)
	for i in _chars.size():
		var rest: Vector2 = _rest[i]
		match phase:
			Phase.ASSEMBLE:
				var p: float = clampf((u - _in_delay[i]) / span, 0.0, 1.0)
				var e: float = 1.0 - pow(1.0 - p, 3.0)
				_pos[i] = rest + _in_unit[i] * in_px * (1.0 - e)
				_alpha[i] = smoothstep(0.0, 0.6, p)
				_glow[i] = _alpha[i] * (config.glow_strength + config.glow_flight_boost * (1.0 - e))
			Phase.DISPERSE:
				var p: float = clampf((u - _out_delay[i]) / span, 0.0, 1.0)
				var e: float = p * p
				_pos[i] = rest + (_out_unit[i] * out_px + rise) * e
				_alpha[i] = 1.0 - smoothstep(0.25, 1.0, p)
				_glow[i] = _alpha[i] * (config.glow_strength + config.glow_flight_boost * e)
			_:
				_pos[i] = rest
				_alpha[i] = 1.0
				_glow[i] = config.glow_strength


func _draw_glow() -> void:
	if phase == Phase.IDLE or config.glow_strength <= 0.0:
		return
	var half := Vector2(_glow_px, _glow_px) * 0.5
	var size := Vector2(_glow_px, _glow_px)
	var centre := Vector2(_advance("M") * 0.5, -float(_font_px) * 0.3)
	for i in _chars.size():
		if _chars[i] == " " or _glow[i] <= 0.004:
			continue
		var c: Color = _glow_color
		c.a = _glow[i]
		_glow_node.draw_texture_rect(_glow_texture, Rect2(_pos[i] + centre - half, size), false, c)


func _draw_text() -> void:
	if phase == Phase.IDLE:
		return
	if _outline_px > 0:
		for i in _chars.size():
			if _chars[i] == " " or _alpha[i] <= 0.004:
				continue
			var o: Color = config.outline_color
			o.a *= _alpha[i]
			_text_node.draw_char_outline(_font, _pos[i], _chars[i], _font_px, _outline_px, o)
	for i in _chars.size():
		if _chars[i] == " " or _alpha[i] <= 0.004:
			continue
		var c: Color = config.text_color
		c.a = _alpha[i]
		_text_node.draw_char(_font, _pos[i], _chars[i], _font_px, c)


## One soft radial blob (white, alpha falling off to the edge); tinted per letter at draw time.
func _make_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex
