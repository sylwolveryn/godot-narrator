class_name NarrationOverlay
extends CanvasLayer
## Presents narration on the overlay layer (above the world, decision-001). The line is laid out once per beat
## into single letters. They assemble like Spike B's narration moment: every letter flies in from a scattered
## spot with an ease-out, staggered left to right, and settles on its place; the line then rests (no per-frame
## work at all) and finally disperses the same calm way (letters drift up and away, fading). A soft additive glow
## tinted by the beat's mood sits behind the letters and is strongest while they fly. No random character swapping.
## Doubt lines (task-042): a share of the letters never settle. They keep a slow sway around their place and a
## gentle brightness dip (NarratorConfig.doubt_*, at most 0.5 Hz); the characters themselves never change.
## Layers (task-062): WORLD lines are vibrant green / purple with a split ghost and glitch ticks (letters jump and
## swap to glitch glyphs); OWN lines take the player's glyph colour, their not-understood words keep switching
## between the real word and a scrambled one (share = 1 - understanding) and a few letters glitch lightly; NARRATOR
## lines keep the look above. World and own lines redraw every frame while on screen (a few seconds).
## Obfuscation (task-067): narrator and world lines (not own lines) are obfuscated by the understanding of the selected
## language, character by character (NarratorConfig obf_*): stable stand-ins, then wild spinning, then near
## characters converging, and a character past its threshold is always right. Words still holding stand-ins pulse in
## a slow wave. Such lines redraw every frame while on screen.
## Cost: two canvas items redrawn only while a morph runs (about 3 batched passes: glow quads, outlines, fills),
## nothing allocated per frame; a doubt line also redraws every frame while it rests, for the few seconds it is on
## screen. Pure presentation: it listens to the Narrator and never writes data.

enum Phase { IDLE, ASSEMBLE, HOLD, DISPERSE }

@export var narrator: Narrator
@export var config: NarratorConfig
@export var display_config: DisplayConfig
## Optional: the own-layer text colour comes from its glyph_color.
@export var player_config: PlayerConfig

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
## Share of letters left unsettled in the current line (0 = a normal line) and, per letter, whether it is one of them.
var _doubt_fraction: float = 0.0
var _doubt: PackedByteArray = PackedByteArray()
## Per unsettled letter: sway phase (x, y) and speed factor, rolled once per layout.
var _doubt_phase: PackedVector2Array = PackedVector2Array()
var _doubt_speed: PackedFloat32Array = PackedFloat32Array()
var _doubt_time: float = 0.0
## Layer of the line on screen (NarrationBeat.Layer), understanding (0..1) for own lines, and per letter: its word
## index, whether that word is broken (own), the word's switch phase and the letter's scrambled stand-in.
var _layer: int = NarrationBeat.Layer.NARRATOR
var _understanding: float = 1.0
var _word_of: PackedInt32Array = PackedInt32Array()
var _broken: PackedByteArray = PackedByteArray()
var _word_phase: PackedFloat32Array = PackedFloat32Array()
var _alt: PackedStringArray = PackedStringArray()
## Obfuscation: per letter whether its word still holds an unresolved character, and whether any letter does.
var _word_unfound: PackedByteArray = PackedByteArray()
var _has_unfound: bool = false


func _ready() -> void:
	if config == null:
		config = NarratorConfig.new()
	if display_config == null:
		display_config = DisplayConfig.new()
	_rng.randomize()
	_font = SystemFont.new()
	_font.font_names = config.font_names
	_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	var fallbacks: Array[Font] = []
	for font_name in config.fallback_font_names:
		var fallback := SystemFont.new()
		fallback.font_names = PackedStringArray([font_name])
		fallback.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		fallbacks.append(fallback)
	_font.fallbacks = fallbacks
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
		narrator.beat_started.connect(_on_beat_started)
		narrator.beat_dissolving.connect(dissolve)


func _process(delta: float) -> void:
	advance(delta)


## Moves the morph on by `delta` seconds (tests call it directly).
func advance(delta: float) -> void:
	if phase == Phase.IDLE:
		return
	_doubt_time += delta
	if phase == Phase.HOLD:
		if _has_doubt() or _is_animated():
			_redraw()
		return
	_t += delta
	if _t >= _duration:
		if phase == Phase.ASSEMBLE:
			phase = Phase.HOLD
			set_process(_has_doubt() or _is_animated())
			_redraw()
		else:
			_clear()
		return
	_redraw()


## True while a line is on screen (assembling, resting or dispersing).
func is_showing() -> bool:
	return phase != Phase.IDLE


func _on_beat_started(beat: NarrationBeat) -> void:
	show_beat(beat, narrator.current_doubt, narrator.current_text, narrator.current_understanding)


## True for layers that move while they rest (world and own lines).
func _is_animated() -> bool:
	return _layer != NarrationBeat.Layer.NARRATOR or _has_unfound


## Layer of the line on screen.
func layer() -> int:
	return _layer


## The letters as shown right now (glitches and switched words included); tests and tools.
func shown_text() -> String:
	var out: String = ""
	for i in _chars.size():
		out += _char_at(i)
	return out


## True when part of the current line is unsettled.
func _has_doubt() -> bool:
	return _doubt_fraction > 0.0 and not _doubt_phase.is_empty()


## Lays the beat out and starts assembling it. Any previous line is replaced. `doubt_fraction` > 0 leaves that
## share of the letters unsettled (a doubt line, see Narrator.doubt_fraction).
## `text` replaces the beat's own text (the line resolved from the narration files); empty = the beat's text.
## `understanding` (0..1) decides how much of an own line is broken.
func show_beat(beat: NarrationBeat, doubt_fraction: float = 0.0, text: String = "", understanding: float = 1.0) -> void:
	_text = text if text != "" else beat.text
	_layer = beat.layer
	_understanding = clampf(understanding, 0.0, 1.0)
	_doubt_fraction = clampf(doubt_fraction, 0.0, 1.0)
	_doubt_time = 0.0
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
	_doubt_fraction = 0.0
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
	_word_of.clear()
	var word_index: int = 0
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
				_word_of.append(word_index)
				x += _advance(word[i])
			word_index += 1


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
	_fill_doubt()
	_fill_layer()


## Rolls the own-layer broken words (share 1 - understanding, at least one word when anything is not understood),
## their switch phases, and every letter's scrambled stand-in.
func _fill_layer() -> void:
	var n: int = _chars.size()
	_broken.resize(n)
	_broken.fill(0)
	_word_phase.resize(n)
	_alt.resize(n)
	var words: int = (_word_of[n - 1] + 1) if n > 0 else 0
	var broken_words: Dictionary[int, float] = {}
	if _layer == NarrationBeat.Layer.OWN and _understanding < 1.0 and words > 0:
		var count: int = clampi(ceili((1.0 - _understanding) * float(words)), 1, words)
		var order: Array[int] = []
		for w in words:
			order.append(w)
		for k in count:
			var pick: int = k + _rng.randi() % (words - k)
			var tmp: int = order[k]
			order[k] = order[pick]
			order[pick] = tmp
			broken_words[order[k]] = _rng.randf() * TAU
	var scramble: String = config.own_scramble_glyphs if _layer == NarrationBeat.Layer.OWN else config.glitch_glyphs
	for i in n:
		var w: int = _word_of[i]
		if broken_words.has(w):
			_broken[i] = 1
			_word_phase[i] = broken_words[w]
		_alt[i] = scramble[_rng.randi() % scramble.length()] if scramble != "" else _chars[i]
	_fill_obfuscation()


## Which words still hold unresolved characters at the current understanding (narrator and world lines only).
func _fill_obfuscation() -> void:
	var n: int = _chars.size()
	_word_unfound.resize(n)
	_word_unfound.fill(0)
	_has_unfound = false
	if not _obfuscates():
		return
	var words: Dictionary[int, bool] = {}
	for i in n:
		if _chars[i] != " " and not is_understood(_chars[i], _understanding):
			words[_word_of[i]] = true
			_has_unfound = true
	for i in n:
		if words.has(_word_of[i]):
			_word_unfound[i] = 1


## True for the layers obfuscated by understanding (never own lines).
func _obfuscates() -> bool:
	return _layer != NarrationBeat.Layer.OWN and _understanding < 1.0


## Understanding (0..1) from which a character is always shown right (hashed, case-insensitive).
func threshold_of(ch: String) -> float:
	var code: int = ch.to_lower().unicode_at(0)
	return lerpf(config.obf_found_min, config.obf_found_max, _noise(code, 0.37))


## True when the character is understood at `understanding` (then it never glitches, in any word).
func is_understood(ch: String, understanding: float) -> bool:
	return understanding >= 1.0 or understanding >= threshold_of(ch)


## What an unresolved character shows right now (the right character once understood).
func obfuscated(i: int) -> String:
	var ch: String = _chars[i]
	if ch == " " or is_understood(ch, _understanding):
		return ch
	var code: int = ch.unicode_at(0)
	if _understanding < config.obf_spin_start:
		return _pick(config.obf_static_glyphs, _noise(code * 31 + i, 1.7), ch)
	var tick: float = floorf(_doubt_time * config.obf_spin_hz + _noise(i, 2.3) * 4.0)
	if _understanding < config.obf_near_start:
		return _pick(config.obf_wild_glyphs, _noise(i * 7 + code, tick), ch)
	# Near stage: closer characters, and the right one more often, as the threshold comes closer.
	var span: float = maxf(threshold_of(ch) - config.obf_near_start, 0.001)
	var t: float = clampf((_understanding - config.obf_near_start) / span, 0.0, 1.0)
	if _noise(i + 13, tick) < t:
		return ch
	var dist: int = maxi(1, roundi(float(config.obf_near_max_dist) * (1.0 - t)))
	var offset: int = int(_noise(i + 29, tick) * float(2 * dist + 1)) - dist
	if offset == 0:
		offset = 1
	return _near(ch, code, offset)


static func _pick(glyphs: String, k: float, fallback: String) -> String:
	if glyphs == "":
		return fallback
	return glyphs[mini(int(k * glyphs.length()), glyphs.length() - 1)]


## A character `offset` code points away, kept inside a-z / A-Z / 0-9 for those, else any printable neighbour.
static func _near(ch: String, code: int, offset: int) -> String:
	var ranges: Array[Vector2i] = [Vector2i(97, 122), Vector2i(65, 90), Vector2i(48, 57)]
	for r in ranges:
		if code >= r.x and code <= r.y:
			var size: int = r.y - r.x + 1
			return String.chr(r.x + posmod(code - r.x + offset, size))
	var other: int = code + offset
	return String.chr(other) if other > 32 and other != 127 else ch


## Deterministic 0..1 noise per letter and tick (no per-frame random state).
static func _noise(i: int, tick: float) -> float:
	var v: float = sin(float(i) * 12.9898 + tick * 78.233) * 43758.5453
	return v - floorf(v)


## True when letter i is in a glitch on the current tick of its layer.
func _glitching(i: int) -> bool:
	match _layer:
		NarrationBeat.Layer.WORLD:
			var share: float = lerpf(config.world_glitch_share, config.world_glitch_min_share, _understanding)
			return _noise(i, floorf(_doubt_time * config.world_glitch_hz)) < share
		NarrationBeat.Layer.OWN:
			return _noise(i, floorf(_doubt_time * config.own_glitch_hz) + 0.5) < config.own_glitch_share
	return false


## The character letter i shows right now: its stand-in while glitching or while its broken word is switched.
func _char_at(i: int) -> String:
	if _chars[i] == " " or _alt.size() != _chars.size():
		return _chars[i]
	if _layer == NarrationBeat.Layer.OWN and _broken[i] != 0 and sin(_word_phase[i] + _doubt_time * TAU * config.own_switch_hz) > 0.0:
		return _alt[i]
	if _obfuscates() and _word_unfound.size() == _chars.size():
		var shown: String = obfuscated(i)
		if shown != _chars[i]:
			return shown
	if _glitching(i):
		var glyphs: String = config.glitch_glyphs if _layer == NarrationBeat.Layer.WORLD else config.own_scramble_glyphs
		if glyphs != "":
			return glyphs[int(_noise(i + 7, floorf(_doubt_time * config.world_glitch_hz)) * glyphs.length()) % glyphs.length()]
	return _chars[i]


## Text colour of letter i (alpha 1).
func _letter_color(i: int) -> Color:
	match _layer:
		NarrationBeat.Layer.WORLD:
			var k: float = 0.5 + 0.5 * sin(_doubt_time * TAU * config.world_wave_hz + float(i) * config.world_letter_phase)
			return config.world_colors[0].lerp(config.world_colors[1], k)
		NarrationBeat.Layer.OWN:
			return player_config.glyph_color if player_config != null else config.own_text_color
	return config.text_color


## Glow colour of letter i (alpha 1).
func _letter_glow(i: int) -> Color:
	match _layer:
		NarrationBeat.Layer.WORLD:
			return _letter_color(i)
		NarrationBeat.Layer.OWN:
			return config.own_glow_color
	return _glow_color.lerp(config.narrator_glow_color, config.narrator_glow_tint)


## Picks the unsettled letters: round(doubt_fraction * visible letters), spread by a partial shuffle of the
## non-space letters, plus their sway phases and speeds.
func _fill_doubt() -> void:
	var n: int = _chars.size()
	_doubt.resize(n)
	_doubt.fill(0)
	_doubt_phase = PackedVector2Array()
	_doubt_speed = PackedFloat32Array()
	if _doubt_fraction <= 0.0:
		return
	var pool: PackedInt32Array = PackedInt32Array()
	for i in n:
		if _chars[i] != " ":
			pool.append(i)
	var count: int = clampi(roundi(_doubt_fraction * float(pool.size())), 0, pool.size())
	_doubt_phase.resize(n)
	_doubt_speed.resize(n)
	for k in count:
		var pick: int = k + _rng.randi() % (pool.size() - k)
		var tmp: int = pool[k]
		pool[k] = pool[pick]
		pool[pick] = tmp
		var i: int = pool[k]
		_doubt[i] = 1
		_doubt_phase[i] = Vector2(_rng.randf() * TAU, _rng.randf() * TAU)
		_doubt_speed[i] = 0.8 + 0.4 * _rng.randf()
	if count == 0:
		_doubt_phase = PackedVector2Array()


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
		if _doubt[i] != 0 and _has_doubt():
			# Unsettled: a calm sway around the place and a slow dip in brightness, never a character swap.
			var w: float = TAU * config.doubt_hz * _doubt_speed[i] * _doubt_time
			var ph: Vector2 = _doubt_phase[i]
			_pos[i] += Vector2(sin(w + ph.x), cos(w * 0.8 + ph.y)) * config.doubt_drift_px * _scale
			var dip: float = 1.0 - config.doubt_alpha_dip * (0.5 + 0.5 * sin(w + ph.y))
			_alpha[i] *= dip
			_glow[i] *= dip
		if _word_unfound.size() == _chars.size() and _word_unfound[i] != 0:
			# Unresolved words pulse: a slow wave runs along the letters, lifting and dimming them a little.
			var wave: float = sin(TAU * config.obf_wave_hz * _doubt_time - float(i) * config.obf_wave_letter_phase)
			var strength: float = 1.0 - _understanding
			_pos[i].y -= (0.5 + 0.5 * wave) * config.obf_wave_px * _scale * strength
			_alpha[i] *= 1.0 - config.obf_wave_alpha * strength * (0.5 - 0.5 * wave)
		if _layer == NarrationBeat.Layer.WORLD and _chars[i] != " " and _glitching(i):
			var tick: float = floorf(_doubt_time * config.world_glitch_hz)
			var jump := Vector2(_noise(i + 3, tick) - 0.5, _noise(i + 5, tick) - 0.5) * 2.0
			_pos[i] += jump * config.world_jitter_px * _scale


func _draw_glow() -> void:
	if phase == Phase.IDLE or config.glow_strength <= 0.0:
		return
	var half := Vector2(_glow_px, _glow_px) * 0.5
	var size := Vector2(_glow_px, _glow_px)
	var centre := Vector2(_advance("M") * 0.5, -float(_font_px) * 0.3)
	for i in _chars.size():
		if _chars[i] == " " or _glow[i] <= 0.004:
			continue
		var c: Color = _letter_glow(i)
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
			_text_node.draw_char_outline(_font, _pos[i], _char_at(i), _font_px, _outline_px, o)
	if _layer == NarrationBeat.Layer.WORLD and config.world_colors.size() >= 2:
		# Split ghosts: green to the left, purple to the right.
		var split := Vector2(config.world_split_px * _scale, 0.0)
		for i in _chars.size():
			if _chars[i] == " " or _alpha[i] <= 0.004:
				continue
			var g: Color = config.world_colors[0]
			g.a = _alpha[i] * config.world_ghost_alpha
			_text_node.draw_char(_font, _pos[i] - split, _char_at(i), _font_px, g)
			var p: Color = config.world_colors[1]
			p.a = _alpha[i] * config.world_ghost_alpha
			_text_node.draw_char(_font, _pos[i] + split, _char_at(i), _font_px, p)
	for i in _chars.size():
		if _chars[i] == " " or _alpha[i] <= 0.004:
			continue
		var c: Color = _letter_color(i)
		c.a = _alpha[i]
		_text_node.draw_char(_font, _pos[i], _char_at(i), _font_px, c)


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
