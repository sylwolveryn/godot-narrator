class_name NarrationDebugOverlay
extends CanvasLayer
## Developer overlay (task-020.07): the narration queue, the text and audio on air and the waiting periods, drawn on
## the left side of the screen. Switched from god ("Queue: on/off") through DevBridge; never instanced otherwise.
## Read-only: it finds the Narrator and NarrationSfx by group and listens to Narrator.debug_note / beat_started.
##
## Sections, top to bottom:
##   STATE    the narrator's state machine with the life of one line (in, hold, out, gap) and where it is now
##   ON AIR   the line on screen
##   NEXT UP  what plays next, in the order the narrator takes it: chained layers, reactive FIFO, queue (with its
##            time to live), waiting FIFO (never-heard lines)
##   IDLE     stillness against the idle trigger thresholds
##   AUDIO    mood and voice playback; the voice bar marks where the line leaves the screen
##   HISTORY  the last seconds of text state, voice and mood as strips; ticks = a line started
##   LOG      every queue decision (trigger, queued, dropped, waiting, started, preempted)

@export var panel_width: float = 420.0
@export var font_size: int = 12
@export var padding: float = 8.0
## Redraws (and history samples) per second; the panel is not redrawn every frame.
@export var redraw_hz: float = 5.0
@export var history_seconds: float = 30.0
@export var log_lines: int = 16
@export var canvas_layer_index: int = 120
@export var background: Color = Color(0.02, 0.03, 0.05, 0.84)

const STATE_COLORS: Array[Color] = [
	Color(0.35, 0.35, 0.38), # FREE
	Color(0.30, 0.80, 0.45), # SHOWING
	Color(0.95, 0.70, 0.25), # DISSOLVING
	Color(0.35, 0.55, 0.95), # GAP
	Color(0.95, 0.30, 0.30), # PREEMPTING
]
const SEG_IN := Color(0.25, 0.60, 0.35)
const SEG_HOLD := Color(0.30, 0.80, 0.45)
const SEG_OUT := Color(0.95, 0.70, 0.25)
const SEG_GAP := Color(0.35, 0.55, 0.95)
const VOICE_COLOR := Color(0.85, 0.45, 0.95)
const MOOD_COLOR := Color(0.40, 0.85, 0.90)
const TEXT_COLOR := Color(0.88, 0.90, 0.92)
const DIM_COLOR := Color(0.55, 0.58, 0.62)
const HEAD_COLOR := Color(1.0, 0.85, 0.40)
const WARN_COLOR := Color(1.0, 0.45, 0.35)
const TRACK_COLOR := Color(1, 1, 1, 0.10)
const KIND_COLORS: Dictionary[StringName, Color] = {
	&"trigger": Color(0.80, 0.82, 0.85),
	&"queue": Color(0.45, 0.70, 1.0),
	&"start": Color(0.35, 0.90, 0.50),
	&"wait": Color(1.0, 0.80, 0.35),
	&"drop": Color(0.60, 0.60, 0.62),
	&"preempt": Color(1.0, 0.40, 0.40),
	&"run": Color(0.85, 0.55, 1.0),
	&"warn": Color(1.0, 0.45, 0.35),
}
const LAYER_NAMES: PackedStringArray = ["WORLD", "OWN", "NARR"]
## Shaped lines kept for reuse (static labels and repeated log lines are shaped once); cleared when it grows past this.
@export var text_cache_size: int = 300
## History sample value for "nothing".
const NONE: int = 255

var _panel: Control
var _font: Font
var _narrator: Narrator
var _sfx: NarrationSfx
var _redraw_left: float = 0.0
var _t0: int = 0
var _log_text: PackedStringArray = PackedStringArray()
var _log_kind: Array[StringName] = []
var _hist_state := PackedByteArray()
var _hist_voice := PackedByteArray()
var _hist_mood := PackedByteArray()
var _hist_mark := PackedByteArray()
var _hist_head: int = 0
var _mark_pending: bool = false
var _voice_event: String = ""
var _voice_was_playing: bool = false
var _voice_pos: float = 0.0
var _voice_len: float = 0.0
## The beat whose voice is playing (to mark where its line leaves the screen).
var _voice_beat: NarrationBeat
var _mood_name: String = ""
## Text -> shaped line (TextServer shaping is the costly part of drawing text).
var _shaped: Dictionary[String, TextLine] = {}
## Microseconds the last panel draw took (shown in the header).
var _draw_usec: int = 0


func _ready() -> void:
	layer = canvas_layer_index
	_t0 = Time.get_ticks_msec()
	_font = ThemeDB.fallback_font
	var samples: int = maxi(1, roundi(history_seconds * redraw_hz))
	# Packed arrays are values: resize each member, not a loop copy.
	_hist_state.resize(samples)
	_hist_state.fill(NONE)
	_hist_voice.resize(samples)
	_hist_voice.fill(NONE)
	_hist_mood.resize(samples)
	_hist_mood.fill(NONE)
	_hist_mark.resize(samples)
	_hist_mark.fill(0)
	_panel = Control.new()
	_panel.name = "NarrationDebugPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.clip_contents = true
	_panel.draw.connect(_draw_panel)
	add_child(_panel)
	get_viewport().size_changed.connect(_fit)
	_fit()
	set_active(false)


## Shows or hides the overlay; hidden it does no work.
func set_active(on: bool) -> void:
	visible = on
	set_process(on)
	if on:
		_redraw_left = 0.0


func _fit() -> void:
	_panel.position = Vector2.ZERO
	_panel.size = Vector2(panel_width, get_viewport().get_visible_rect().size.y)


func _process(delta: float) -> void:
	_bind()
	_track_voice()
	_redraw_left -= delta
	if _redraw_left > 0.0:
		return
	_redraw_left = 1.0 / maxf(redraw_hz, 1.0)
	_sample()
	_panel.queue_redraw()


## Finds the narrator and sfx (the main scene may load after this autoload's child).
func _bind() -> void:
	if not is_instance_valid(_narrator):
		_narrator = get_tree().get_first_node_in_group(Narrator.GROUP) as Narrator
		if _narrator != null:
			_narrator.debug_note.connect(_on_note)
			_narrator.beat_started.connect(_on_beat_started)
			_narrator.beat_dissolving.connect(_on_beat_dissolving)
			_on_note(&"run", "narrator found")
	if not is_instance_valid(_sfx):
		_sfx = get_tree().get_first_node_in_group(NarrationSfx.GROUP) as NarrationSfx


func _track_voice() -> void:
	if _sfx == null:
		_voice_was_playing = false
		return
	var v: AudioStreamPlayer = _sfx.voice_player()
	_voice_was_playing = v.playing
	if v.playing:
		_voice_pos = v.get_playback_position()
		_voice_len = v.stream.get_length() if v.stream != null else 0.0


func _seconds() -> float:
	return float(Time.get_ticks_msec() - _t0) / 1000.0


func _on_note(kind: StringName, text: String) -> void:
	_log_text.append("%6.1f  %s" % [_seconds(), text])
	_log_kind.append(kind)
	while _log_text.size() > log_lines:
		_log_text.remove_at(0)
		_log_kind.remove_at(0)


func _on_beat_dissolving(fast: bool) -> void:
	_on_note(&"preempt" if fast else &"start", "line leaves%s" % (" FAST (preempted)" if fast else ""))


## Runs after NarrationSfx's handler (connected later), so the voice player already holds the new voice; the state
## sampled last frame tells whether an older voice was cut.
func _on_beat_started(beat: NarrationBeat) -> void:
	_mark_pending = true
	var layer_name: String = LAYER_NAMES[beat.layer] if beat.layer < LAYER_NAMES.size() else "?"
	_on_note(&"start", "ON AIR %s [%s] %s" % [beat.id, layer_name, String(beat.event)])
	_mood_name = String(beat.mood)
	if _narrator.current_voice == null:
		return
	if _voice_was_playing and _voice_len > 0.0 and _voice_pos < _voice_len:
		_on_note(&"warn", "VOICE CUT: %s at %.1f / %.1fs" % [_voice_event, _voice_pos, _voice_len])
	_voice_event = String(NarrationLibrary.event_of(beat))
	_voice_beat = beat
	_voice_pos = 0.0
	_voice_len = _narrator.current_voice.get_length()
	var on_screen: float = _line_seconds()
	if _voice_len > on_screen:
		_on_note(&"warn", "voice %.1fs outlasts the line on screen %.1fs" % [_voice_len, on_screen])


## Seconds a line is on screen: morph in + hold + morph out.
func _line_seconds() -> float:
	var c: NarratorConfig = _narrator.config
	return c.morph_in_seconds + c.beat_hold_seconds + c.morph_out_seconds


func _sample() -> void:
	var n: int = _hist_state.size()
	_hist_head = (_hist_head + 1) % n
	_hist_state[_hist_head] = int(_narrator.state) if _narrator != null else NONE
	_hist_voice[_hist_head] = 1 if _voice_was_playing else NONE
	var mood_on: bool = _sfx != null and _sfx.mood_player().playing
	_hist_mood[_hist_head] = 1 if mood_on else NONE
	_hist_mark[_hist_head] = 1 if _mark_pending else 0
	_mark_pending = false


# ------------------------------------------------------------------ drawing

func _draw_panel() -> void:
	var t0: int = Time.get_ticks_usec()
	_draw_sections()
	_draw_usec = Time.get_ticks_usec() - t0


func _draw_sections() -> void:
	var p: Control = _panel
	p.draw_rect(Rect2(Vector2.ZERO, p.size), background)
	var x: float = padding
	var w: float = p.size.x - padding * 2.0
	var y: float = padding
	var lh: float = _font.get_height(font_size) + 2.0
	y = _text(x, y, "NARRATION QUEUE  (debug, god: Queue)   draw %.1f ms @ %.0f Hz" % [_draw_usec / 1000.0, redraw_hz], HEAD_COLOR)
	if _narrator == null:
		_text(x, y, "no Narrator in this scene", WARN_COLOR)
		return
	var n: Narrator = _narrator
	var c: NarratorConfig = n.config
	y = _text(x, y, "run: %s   t=%.1fs" % ["active" if n.is_run_active() else "NOT ACTIVE (only death/reactive lines)", _seconds()], DIM_COLOR)
	y += 4.0

	# STATE + life of a line
	y = _head(x, y, w, "STATE")
	var st: int = int(n.state)
	var st_name: String = Narrator.State.keys()[st]
	p.draw_rect(Rect2(x, y, 96.0, lh), STATE_COLORS[st])
	_text_at(x + 4.0, y, st_name, Color.BLACK)
	var left: float = n.phase_left()
	var plen: float = n.phase_length()
	var st_info: String = "free: the next line starts at once" if n.state == Narrator.State.FREE else "%.1fs left of %.1fs" % [left, plen]
	_text_at(x + 104.0, y, st_info, TEXT_COLOR)
	y += lh + 4.0
	var segs: Array = [["IN", c.morph_in_seconds, SEG_IN], ["HOLD", c.beat_hold_seconds, SEG_HOLD],
		["OUT", c.morph_out_seconds, SEG_OUT], ["GAP (silence)", c.beat_gap_seconds, SEG_GAP]]
	var total: float = 0.0
	for s: Array in segs:
		total += s[1]
	var bar_h: float = 10.0
	var sx: float = x
	for s: Array in segs:
		var sw: float = w * s[1] / maxf(total, 0.001)
		p.draw_rect(Rect2(sx, y, sw - 1.0, bar_h), Color(s[2], 0.45))
		sx += sw
	var cursor: float = -1.0
	var elapsed: float = plen - left
	match n.state:
		Narrator.State.SHOWING:
			cursor = elapsed
		Narrator.State.DISSOLVING:
			cursor = c.morph_in_seconds + c.beat_hold_seconds + elapsed
		Narrator.State.GAP:
			cursor = c.morph_in_seconds + c.beat_hold_seconds + c.morph_out_seconds + elapsed
	if cursor >= 0.0:
		var cx: float = x + w * clampf(cursor / maxf(total, 0.001), 0.0, 1.0)
		p.draw_rect(Rect2(x, y, cx - x, bar_h), Color(1, 1, 1, 0.35))
		p.draw_line(Vector2(cx, y - 3.0), Vector2(cx, y + bar_h + 3.0), Color.WHITE, 2.0)
	if n.state == Narrator.State.PREEMPTING:
		p.draw_rect(Rect2(x, y, w * clampf(elapsed / maxf(plen, 0.001), 0.0, 1.0), bar_h), STATE_COLORS[4])
	var lx: float = x
	for s: Array in segs:
		var seg_label: String = "%s %.1fs   " % [s[0], s[1]]
		_text_at(lx, y + bar_h + 1.0, seg_label, s[2])
		lx += _font.get_string_size(seg_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	y += bar_h + lh + 2.0
	y = _text(x, y, "chain + reactive lines start at OUT end (skip GAP); queue waits for FREE", DIM_COLOR)
	y += 4.0

	# ON AIR
	y = _head(x, y, w, "ON AIR (text)")
	if n.current != null and n.state != Narrator.State.FREE and n.state != Narrator.State.GAP:
		var b: NarrationBeat = n.current
		y = _text(x, y, "%s  [%s]  %s  mood=%s  heard=%d%s" % [b.id, LAYER_NAMES[b.layer], String(NarrationLibrary.event_of(b)),
			String(b.mood), n.hearings(b.id), "  doubt=%.2f" % n.current_doubt if n.current_doubt > 0.0 else ""], TEXT_COLOR)
		p.draw_multiline_string(_font, Vector2(x, y + _font.get_ascent(font_size)), "\"%s\"" % n.current_text,
			HORIZONTAL_ALIGNMENT_LEFT, w, font_size, 2, DIM_COLOR)
		y += lh * 2.0
	else:
		y = _text(x, y, "(nothing on screen)", DIM_COLOR)
	y += 4.0

	# NEXT UP
	y = _head(x, y, w, "NEXT UP (in the order the narrator takes them)")
	var any: bool = false
	for b: NarrationBeat in n.chained():
		y = _text(x, y, "1 CHAIN   [%s] %s   after OUT, no gap" % [LAYER_NAMES[b.layer], b.id], SEG_HOLD)
		any = true
	for b: NarrationBeat in n.reactive_beats():
		y = _text(x, y, "2 REACT   %s  (%s)  when FREE or GAP" % [b.id, String(b.event)], KIND_COLORS[&"run"])
		any = true
	if n.queued != null:
		var q: NarrationBeat = n.queued
		var exempt: bool = c.ttl_exempt_events.has(q.event)
		y = _text(x, y, "3 QUEUE   %s  prio %d  %s" % [q.id, n.queued_priority(), "TTL-exempt" if exempt else "TTL %.1f / %.1fs" % [n.queued_age(), c.queue_ttl_seconds]], KIND_COLORS[&"queue"])
		if not exempt:
			var frac: float = clampf(n.queued_age() / maxf(c.queue_ttl_seconds, 0.001), 0.0, 1.0)
			p.draw_rect(Rect2(x, y, w, 5.0), TRACK_COLOR)
			p.draw_rect(Rect2(x, y, w * frac, 5.0), WARN_COLOR.lerp(KIND_COLORS[&"queue"], 1.0 - frac))
			y += 8.0
		any = true
	for b: NarrationBeat in n.waiting():
		y = _text(x, y, "4 WAIT    %s  (never heard, next free queue)" % b.id, KIND_COLORS[&"wait"])
		any = true
	if not any:
		y = _text(x, y, "(empty)", DIM_COLOR)
	y += 4.0

	# IDLE
	if n.is_run_active():
		y = _head(x, y, w, "IDLE (stillness -> idle triggers)")
		var top: float = maxf(c.idle_long_seconds, 0.001)
		var still: float = n.still_time()
		p.draw_rect(Rect2(x, y, w, 6.0), TRACK_COLOR)
		p.draw_rect(Rect2(x, y, w * clampf(still / top, 0.0, 1.0), 6.0), DIM_COLOR)
		for t: float in [c.idle_seconds, c.idle_mid_seconds, c.idle_long_seconds]:
			var tx: float = x + w * clampf(t / top, 0.0, 1.0)
			p.draw_line(Vector2(tx, y - 2.0), Vector2(tx, y + 8.0), HEAD_COLOR, 1.0)
		y += 8.0
		y = _text(x, y, "still %.1fs   short %.0f / mid %.0f / long %.0fs" % [still, c.idle_seconds, c.idle_mid_seconds, c.idle_long_seconds], DIM_COLOR)
		y += 4.0

	# AUDIO
	y = _head(x, y, w, "AUDIO")
	y = _draw_audio(x, y, w, "MOOD ", _mood_name, _sfx.mood_player() if _sfx != null else null, MOOD_COLOR, -1.0)
	var leave: float = -1.0
	if _voice_beat != null and n.current == _voice_beat:
		match n.state:
			Narrator.State.SHOWING:
				leave = _voice_pos + left + c.morph_out_seconds
			Narrator.State.DISSOLVING, Narrator.State.PREEMPTING:
				leave = _voice_pos + left
	y = _draw_audio(x, y, w, "VOICE", _voice_event, _sfx.voice_player() if _sfx != null else null, VOICE_COLOR, leave)
	y += 4.0

	# HISTORY
	y = _head(x, y, w, "HISTORY (last %.0fs, now at right)" % history_seconds)
	y = _strip(x, y, w, "text", _hist_state, true)
	y = _strip(x, y, w, "voice", _hist_voice, false, VOICE_COLOR)
	y = _strip(x, y, w, "mood", _hist_mood, false, MOOD_COLOR)
	y += 4.0

	# LOG
	y = _head(x, y, w, "LOG (newest last)")
	for i in _log_text.size():
		y = _text(x, y, _log_text[i], KIND_COLORS.get(_log_kind[i], TEXT_COLOR))


func _draw_audio(x: float, y: float, w: float, label: String, sound: String, player: AudioStreamPlayer, color: Color, leave_at: float) -> float:
	var lw: float = 48.0
	_text_at(x, y, label, color)
	var bx: float = x + lw
	var bw: float = w - lw
	var bh: float = 8.0
	var by: float = y + 3.0
	_panel.draw_rect(Rect2(bx, by, bw, bh), TRACK_COLOR)
	var info: String = "silent"
	if player != null and player.playing and player.stream != null:
		var length: float = maxf(player.stream.get_length(), 0.001)
		var pos: float = player.get_playback_position()
		_panel.draw_rect(Rect2(bx, by, bw * clampf(pos / length, 0.0, 1.0), bh), color)
		info = "%s  %.1f / %.1fs" % [sound, pos, length]
		if leave_at >= 0.0:
			var lx: float = bx + bw * clampf(leave_at / length, 0.0, 1.0)
			_panel.draw_line(Vector2(lx, by - 3.0), Vector2(lx, by + bh + 3.0), WARN_COLOR if leave_at < length else Color.WHITE, 2.0)
			info += "   line gone at %.1fs%s" % [leave_at, " (voice runs on)" if leave_at < length else ""]
	y += bh + 6.0
	return _text(bx, y, info, DIM_COLOR)


## One history row: oldest sample at the left; runs of equal value are drawn as one rect.
func _strip(x: float, y: float, w: float, label: String, data: PackedByteArray, states: bool, color: Color = Color.WHITE) -> float:
	var lw: float = 48.0
	_text_at(x, y, label, DIM_COLOR)
	var bx: float = x + lw
	var bw: float = w - lw
	var bh: float = 9.0
	var by: float = y + 3.0
	_panel.draw_rect(Rect2(bx, by, bw, bh), TRACK_COLOR)
	var count: int = data.size()
	var step: float = bw / float(count)
	var run_start: int = 0
	var run_value: int = data[(_hist_head + 1) % count]
	for i in range(1, count + 1):
		var value: int = data[(_hist_head + 1 + i) % count] if i < count else -1
		if value == run_value:
			continue
		if run_value != NONE:
			var col: Color = STATE_COLORS[run_value] if states and run_value < STATE_COLORS.size() else color
			if not (states and run_value == int(Narrator.State.FREE)):
				_panel.draw_rect(Rect2(bx + run_start * step, by, (i - run_start) * step, bh), col)
		run_start = i
		run_value = value
	if states:
		for i in count:
			if _hist_mark[(_hist_head + 1 + i) % count] == 1:
				var mx: float = bx + i * step
				_panel.draw_line(Vector2(mx, by - 2.0), Vector2(mx, by + bh + 2.0), Color.WHITE, 1.0)
	return y + bh + 6.0


func _head(x: float, y: float, w: float, title: String) -> float:
	_panel.draw_line(Vector2(x, y + 1.0), Vector2(x + w, y + 1.0), Color(1, 1, 1, 0.15), 1.0)
	return _text(x, y + 3.0, title, HEAD_COLOR)


## Draws one line of text at the top-left `(x, y)` and returns the y of the next line.
func _text(x: float, y: float, s: String, color: Color) -> float:
	_text_at(x, y, s, color)
	return y + _font.get_height(font_size) + 2.0


func _text_at(x: float, y: float, s: String, color: Color) -> void:
	var line: TextLine = _shaped.get(s)
	if line == null:
		if _shaped.size() >= text_cache_size:
			_shaped.clear()
		line = TextLine.new()
		line.add_string(s, _font, font_size)
		_shaped[s] = line
	line.draw(_panel.get_canvas_item(), Vector2(x, y), color)
