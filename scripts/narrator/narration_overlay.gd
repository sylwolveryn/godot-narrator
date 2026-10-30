class_name NarrationOverlay
extends CanvasLayer
## Presents narration on the overlay layer (above the ASCII shader, decision-001). Every letter is an
## SDF quad (GlyphQuad, shared atlas): it starts as an abstract shape, morphs into the letter, rises a
## few pixels and starts a moment after the previous letter; it morphs out the same way in reverse.
## Fully legible during the hold. The glow takes the beat's mood tint. Pure presentation: it listens to
## the Narrator and never writes data.

@export var narrator: Narrator
@export var config: NarratorConfig
@export var display_config: DisplayConfig
## Owner of the shared SDF atlas.
@export var ascii: AsciiPostProcess

enum Phase { IDLE, IN, HOLD, OUT }

## One letter of the current line.
class Letter extends RefCounted:
	var character: String = ""
	var quad: GlyphQuad
	## Centre of the letter on screen at rest.
	var centre: Vector2 = Vector2.ZERO
	## Order among the visible letters (drives the stagger).
	var order: int = 0
	var abstract_glyph: int = 0
	var letter_glyph: int = 0
	## Where the letter was when the dissolve began: morph amount, opacity, and whether it was visible.
	var out_amount: float = 1.0
	var out_alpha: float = 1.0
	var out_shown: bool = true

var _atlas: GlyphAtlas
var _pool: Array[GlyphQuad] = []
var _letters: Array[Letter] = []
var _abstract: PackedInt32Array = PackedInt32Array()
var _phase: Phase = Phase.IDLE
var _clock: float = 0.0
var _text: String = ""
var _mood: StringName = &""
var _pending: NarrationBeat
var _scale: float = 1.0
var _stagger_in: float = 0.0
var _stagger_out: float = 0.0
var _morph_out_len: float = 0.0
var _out_started: bool = false


func _ready() -> void:
	if config == null:
		config = NarratorConfig.new()
	if display_config == null:
		display_config = DisplayConfig.new()
	get_viewport().size_changed.connect(_on_resized)
	_scale = display_config.scale_for(get_viewport())
	if narrator != null:
		narrator.beat_started.connect(show_beat)
		narrator.beat_dissolving.connect(dissolve)
	if ascii != null:
		if ascii.atlas.ready:
			_on_atlas_ready()
		else:
			ascii.ready_to_draw.connect(_on_atlas_ready, CONNECT_ONE_SHOT)


## True while a line is on screen (morphing or resolved).
func is_showing() -> bool:
	return _phase != Phase.IDLE


## True once the atlas exists and lines can be drawn.
func is_ready() -> bool:
	return _atlas != null


## True while every letter of the line is fully morphed in (the legible hold).
func is_legible() -> bool:
	return _phase == Phase.HOLD


func _on_atlas_ready() -> void:
	_atlas = ascii.atlas
	_abstract = PackedInt32Array()
	for i in config.abstract_glyphs.length():
		var ch: String = config.abstract_glyphs[i]
		if _atlas.has_char(ch):
			_abstract.append(_atlas.index_of(ch))
	_abstract.append(_atlas.index_of(GlyphAtlas.CIRCLE))
	if _pending != null:
		var beat: NarrationBeat = _pending
		_pending = null
		show_beat(beat)


## Starts morphing a beat in. Any previous line is replaced.
func show_beat(beat: NarrationBeat) -> void:
	if _atlas == null:
		_pending = beat
		return
	_text = beat.text
	_mood = beat.mood
	_build_letters()
	_phase = Phase.IN
	_clock = 0.0
	_out_started = false
	_update_letters()


## Dissolves the current line away (`fast` for a preempting death beat).
func dissolve(fast: bool) -> void:
	if _phase == Phase.IDLE or _phase == Phase.OUT:
		return
	var count: int = maxi(_letters.size(), 1)
	var budget: float = config.preempt_dissolve_seconds if fast else config.morph_out_seconds
	var morph_len: float = config.preempt_dissolve_seconds * config.preempt_morph_share if fast else config.letter_morph_out
	morph_len = minf(morph_len, budget)
	var spread: float = maxf(budget - morph_len, 0.0)
	var stagger: float = spread / float(maxi(count - 1, 1))
	if not fast:
		stagger = minf(stagger, config.letter_stagger_out)
	_morph_out_len = morph_len
	_stagger_out = stagger
	# A dissolve that interrupts the morph in continues from where each letter is (no pop).
	for letter in _letters:
		var state: Vector3 = _in_state(letter) if _phase == Phase.IN else Vector3(1.0, 1.0, 1.0)
		letter.out_amount = state.x
		letter.out_alpha = state.y
		letter.out_shown = state.z > 0.5
	_phase = Phase.OUT
	_clock = 0.0


## (morph amount, opacity, started) of a letter during the morph in.
func _in_state(letter: Letter) -> Vector3:
	var p: float = (_clock - _stagger_in * float(letter.order)) / maxf(config.letter_morph_in, 0.001)
	var started: float = 1.0 if p > 0.0 else 0.0
	p = clampf(p, 0.0, 1.0)
	return Vector3(_eased(p), smoothstep(0.0, config.abstract_alpha_share, p), started)


func _on_resized() -> void:
	_scale = display_config.scale_for(get_viewport())
	if _phase != Phase.IDLE and _atlas != null:
		var keep_clock: float = _clock
		var keep_phase: Phase = _phase
		_build_letters()
		_phase = keep_phase
		_clock = keep_clock
		_update_letters()


func _process(delta: float) -> void:
	if _phase == Phase.IDLE:
		return
	_clock += delta
	if _phase == Phase.IN and _clock >= _in_duration():
		_phase = Phase.HOLD
	elif _phase == Phase.OUT and _clock >= _out_duration():
		_hide_all()
		return
	_update_letters()


func _in_duration() -> float:
	var count: int = _letters.size()
	return config.letter_morph_in + _stagger_in * float(maxi(count - 1, 0))


func _out_duration() -> float:
	var count: int = _letters.size()
	return _morph_out_len + _stagger_out * float(maxi(count - 1, 0))


func _hide_all() -> void:
	_phase = Phase.IDLE
	for quad in _pool:
		quad.visible = false
	_letters.clear()


## Lays the line out (word wrap, centred) and assigns a quad to every visible character.
func _build_letters() -> void:
	_letters.clear()
	for quad in _pool:
		quad.visible = false
	var view: Vector2 = get_viewport().get_visible_rect().size
	var font_px: float = config.font_size * _scale
	var k: float = font_px / _atlas.font_px
	var max_width: float = minf(view.x * (1.0 - 2.0 * config.side_margin), config.max_text_width * _scale)
	var space_w: float = _atlas.advance_of(GlyphAtlas.BLANK) * k
	var lines: Array[Array] = []
	var widths: PackedFloat32Array = PackedFloat32Array()
	var line: Array = []
	var line_w: float = 0.0
	for word in _text.split(" ", false):
		var word_w: float = 0.0
		for i in word.length():
			word_w += _atlas.advance_of(word[i]) * k
		if not line.is_empty() and line_w + space_w + word_w > max_width:
			lines.append(line)
			widths.append(line_w)
			line = []
			line_w = 0.0
		if not line.is_empty():
			line.append({"ch": " ", "x": line_w, "w": space_w})
			line_w += space_w
		for i in word.length():
			var adv: float = _atlas.advance_of(word[i]) * k
			line.append({"ch": word[i], "x": line_w, "w": adv})
			line_w += adv
	if not line.is_empty():
		lines.append(line)
		widths.append(line_w)

	var line_h: float = _atlas.tile_px.y * k * config.line_spacing
	var top: float = view.y * config.vertical_anchor - line_h * float(lines.size()) * 0.5
	var tint: Color = config.mood_tints.get(_mood, config.text_color)
	var order: int = 0
	var used: int = 0
	for li in lines.size():
		var x0: float = (view.x - widths[li]) * 0.5
		var y: float = top + line_h * (float(li) + 0.5)
		for item: Dictionary in lines[li]:
			var ch: String = item["ch"]
			if ch == " ":
				continue
			var letter := Letter.new()
			letter.character = ch
			letter.quad = _quad_at(used)
			used += 1
			letter.centre = Vector2(x0 + float(item["x"]) + float(item["w"]) * 0.5, y)
			letter.order = order
			letter.letter_glyph = _atlas.index_of(ch)
			var h: int = hash(ch) + order * 7
			letter.abstract_glyph = _abstract[absi(h) % _abstract.size()] if not _abstract.is_empty() else 0
			order += 1
			letter.quad.fit_to_font(font_px)
			letter.quad.set_shape(letter.abstract_glyph, letter.letter_glyph, 0.0)
			letter.quad.set_colors(config.text_color, tint, config.glow_strength, config.glow_radius)
			letter.quad.visible = false
			_letters.append(letter)
	var count: int = _letters.size()
	var spread: float = maxf(config.morph_in_seconds - config.letter_morph_in, 0.0)
	_stagger_in = minf(config.letter_stagger_in, spread / float(maxi(count - 1, 1)))
	_stagger_out = minf(config.letter_stagger_out, maxf(config.morph_out_seconds - config.letter_morph_out, 0.0) / float(maxi(count - 1, 1)))
	_morph_out_len = config.letter_morph_out


func _quad_at(index: int) -> GlyphQuad:
	while _pool.size() <= index:
		var quad: GlyphQuad = GlyphQuad.new().setup(_atlas)
		quad.set_pad(config.glow_pad)
		quad.set_outline(config.outline_color, config.outline_width)
		quad.visible = false
		add_child(quad)
		_pool.append(quad)
	return _pool[index]


## Shape, opacity and offset of every letter at the current clock.
func _update_letters() -> void:
	var rise: float = config.letter_rise_px * _scale
	for letter in _letters:
		var amount: float = 1.0
		var alpha: float = 1.0
		var lift: float = 0.0
		var started: bool = true
		if _phase == Phase.IN:
			var state: Vector3 = _in_state(letter)
			amount = state.x
			alpha = state.y
			started = state.z > 0.5
			lift = rise * (1.0 - amount)
		elif _phase == Phase.OUT:
			started = letter.out_shown
			var q: float = clampf((_clock - _stagger_out * float(letter.order)) / maxf(_morph_out_len, 0.001), 0.0, 1.0)
			# Continue from the morph-in state: q starts where the letter already was.
			var q_start: float = 1.0 - letter.out_amount
			var progress: float = q_start + (1.0 - q_start) * q
			amount = 1.0 - _eased(progress)
			alpha = minf(letter.out_alpha, 1.0 - smoothstep(0.5, 1.0, progress))
			lift = rise * (1.0 - letter.out_amount) * (1.0 - q)
		letter.quad.visible = started and alpha > 0.0
		if not letter.quad.visible:
			continue
		letter.quad.set_morph_amount(amount)
		letter.quad.set_alpha(alpha)
		letter.quad.centre_on(letter.centre + Vector2(0.0, lift))


func _eased(value: float) -> float:
	return Tween.interpolate_value(0.0, 1.0, clampf(value, 0.0, 1.0), 1.0, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
