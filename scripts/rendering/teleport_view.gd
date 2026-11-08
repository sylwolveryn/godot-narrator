class_name TeleportView
extends Node3D
## Teleports (task-068), presentation side. Draws every pad of the built map: working pads as a flat ASCII frame over
## their 3x3 footprint (one Label3D lying on the floor, square glyph pitch) with their channel character standing in
## the middle (one billboard Label3D); broken groups as dim cracked glyphs over their T cells (one flat Label3D). Like
## the gargoyle, a pad is hidden until a footprint cell is seen or remembered, and tinted while only remembered.
## The trip (SignalBus.teleport_started .. teleport_finished, timeline from TeleportConfig):
##  1. glow-in at the source: the pad glows up, colour waves ripple out over the floor and walls;
##  2. travel: the camera eases (in / out) to the destination through CameraRig.override_view(); with several
##     candidates it zooms out fully (the rig's zoom_max), half-strength pings cycle back and forth over the candidates,
##     then it zooms back in on the chosen pad;
##  3. arrival (teleport_arrived): an intense wave on the receiving pad, area and strength x the candidate count.
## The waves are uniforms of the glyph-surface material (wave_count / wave_geo / wave_col, shaders/glyph_surface.gdshader),
## at most MAX_WAVES at once (the oldest is replaced). Processing runs only while a trip, a wave or a glow lasts.
## Reads MapLoader / MapReveal and the signals; never writes data.

const MAX_WAVES: int = 8
const SPACE: String = " "
## Fallback width of one glyph as a fraction of the font size (when the font cannot be measured).
const GLYPH_ASPECT_FALLBACK: float = 0.6
## Glow below this counts as off (the pad drops back to its idle look, processing may stop).
const GLOW_EPSILON: float = 0.01
## Pads glowing at least this much are drawn even when hidden (candidates far away in the dark).
const FORCE_SHOW_GLOW: float = 0.05

@export var config: TeleportConfig
@export var map_loader: MapLoader
## Optional: without it every pad is shown as seen.
@export var map_reveal: MapReveal
## Optional: the rig the travel drives (override_view / release_override).
@export var camera_rig: CameraRig
## The glyph-surface material of the world (its wave uniforms).
@export var surface_material: ShaderMaterial


class Piece:
	var pad: TeleportPad
	var root: Node3D
	var frame: Label3D
	## Null for a broken pad.
	var rune: Label3D
	## Cracks drawn instead of frame and rune while a working pad is destroyed (task-073); made on the first hit.
	var cracks: Label3D
	var state: int = 0
	var glow: float = 0.0


class Wave:
	var centre: Vector2 = Vector2.ZERO
	var born: float = 0.0
	var scale: float = 1.0
	var strength: float = 1.0
	var color: Color = Color.WHITE


var _pieces: Array[Piece] = []
## Working pads by their centre cell (pad index in MapData.teleports -> piece).
var _pad_pieces: Array[Piece] = []
var _font: SystemFont
var _waves: Array[Wave] = []
var _clock: float = 0.0
var _geo := PackedVector4Array()
var _col := PackedVector4Array()

## Trip state (from the signals).
var _trip: bool = false
var _trip_t: float = 0.0
var _duration: float = 0.0
var _from := Vector3.ZERO
var _cands: Array[Vector3] = []
var _chosen: int = 0
var _overview := Vector3.ZERO
var _zoom0: float = 1.0
var _next_ripple: int = 0
var _next_ping_at: float = 0.0
var _ping_step: int = 0
var _arrived: bool = false
var _arrival_scale: float = 1.0
var _arrival_at: float = 0.0
var _next_arrival_ripple: int = 0
## Highest zoom the travel asked for in the running / last trip (tests).
var _max_zoom_seen: float = 0.0


func _ready() -> void:
	if config == null:
		config = TeleportConfig.new()
	_geo.resize(MAX_WAVES)
	_col.resize(MAX_WAVES)
	_font = SystemFont.new()
	_font.font_names = config.font_names
	_font.font_weight = config.font_weight
	set_process(false)
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.teleport_started.connect(_on_teleport_started)
	SignalBus.teleport_arrived.connect(_on_teleport_arrived)
	SignalBus.teleport_finished.connect(_on_teleport_finished)
	SignalBus.destructible_destroyed.connect(func(kind: StringName, rect: Rect2i, _w: Vector3, _c: StringName) -> void:
		if kind == TeleportSystem.KIND:
			_refresh_pad(rect))
	SignalBus.destructible_restored.connect(func(kind: StringName, rect: Rect2i) -> void:
		if kind == TeleportSystem.KIND:
			_refresh_pad(rect))
	if map_reveal != null:
		map_reveal.cells_seen.connect(refresh_reveal)
	if map_loader != null:
		map_loader.map_built.connect(_on_map_built)
		if not map_loader.data.is_empty():
			_on_map_built(map_loader.data)


func _process(delta: float) -> void:
	_clock += delta
	if _trip:
		_step_trip(delta)
	elif _arrived:
		_trip_t += delta
		_step_arrival(_trip_t)
	_step_glows(delta)
	_push_waves()
	if not _trip and _waves.is_empty() and not _any_glow() and not _arrival_pending():
		_arrived = false
		set_process(false)


## Number of drawn pads (working and broken).
func piece_count() -> int:
	return _pieces.size()


## The flat frame label of piece `index` (working pads first in map order, then broken groups).
func piece_frame(index: int) -> Label3D:
	return _pieces[index].frame


## The channel rune label of piece `index` (null for a broken pad).
func piece_rune(index: int) -> Label3D:
	return _pieces[index].rune


func piece_pad(index: int) -> TeleportPad:
	return _pieces[index].pad


func piece_visible(index: int) -> bool:
	return _pieces[index].root.visible


func piece_glow(index: int) -> float:
	return _pieces[index].glow


## Waves alive right now (the shader's wave_count).
func wave_count() -> int:
	return mini(_waves.size(), MAX_WAVES)


## Strongest wave strength alive right now.
func max_wave_strength() -> float:
	var best: float = 0.0
	for w in _waves:
		best = maxf(best, w.strength)
	return best


## Largest wave scale alive right now.
func max_wave_scale() -> float:
	var best: float = 0.0
	for w in _waves:
		best = maxf(best, w.scale)
	return best


## True while a trip is being presented.
func is_presenting() -> bool:
	return _trip


## Highest zoom the travel asked the rig for during the running / last trip.
func max_zoom_seen() -> float:
	return _max_zoom_seen


## Re-reads the reveal state of every pad footprint.
func refresh_reveal() -> void:
	for piece in _pieces:
		piece.state = _footprint_state(piece.pad.rect)
		_apply_look(piece)


func _on_map_built(map: MapData) -> void:
	for piece in _pieces:
		piece.root.free()
	_pieces.clear()
	_pad_pieces.clear()
	for pad in map.teleports:
		var piece: Piece = _make_pad(pad)
		_pieces.append(piece)
		_pad_pieces.append(piece)
	for pad in map.broken_teleports:
		_pieces.append(_make_broken(pad))
	call_deferred(&"refresh_reveal")


func _on_run_started(_run_index: int) -> void:
	_end_trip()
	_arrived = false
	_waves.clear()
	for piece in _pieces:
		piece.glow = 0.0
	_push_waves()
	call_deferred(&"refresh_reveal")


# --- Trip -----------------------------------------------------------------------------------------------------------

func _on_teleport_started(from_centre: Vector3, candidates: Array[Vector3], chosen_index: int, duration: float) -> void:
	_trip = true
	_trip_t = 0.0
	_duration = duration
	_from = from_centre
	_cands = candidates.duplicate()
	_chosen = clampi(chosen_index, 0, maxi(candidates.size() - 1, 0))
	_overview = Vector3.ZERO
	for c in _cands:
		_overview += c
	_overview /= maxf(float(_cands.size()), 1.0)
	_zoom0 = camera_rig.requested_zoom() if camera_rig != null else 1.0
	_max_zoom_seen = _zoom0
	_next_ripple = 0
	_ping_step = 0
	_next_ping_at = config.glow_in_seconds
	_arrived = false
	_next_arrival_ripple = 0
	_arrival_scale = clampf(float(_cands.size()), 1.0, maxf(config.max_candidate_multiplier, 1.0))
	set_process(true)


func _on_teleport_arrived(_centre: Vector3, candidate_count: int) -> void:
	_arrived = true
	_arrival_at = _trip_t
	_arrival_scale = clampf(float(candidate_count), 1.0, maxf(config.max_candidate_multiplier, 1.0))
	set_process(true)


func _on_teleport_finished() -> void:
	_end_trip()


func _arrival_pending() -> bool:
	return _arrived and _next_arrival_ripple < maxi(config.arrival_ripples, 1)


func _end_trip() -> void:
	_trip = false
	if camera_rig != null:
		camera_rig.release_override()


func _step_trip(delta: float) -> void:
	_trip_t += delta
	var t: float = _trip_t
	var glow_in: float = config.glow_in_seconds
	var travel_end: float = maxf(_duration - config.arrival_seconds, glow_in)
	var dest: Vector3 = _cands[_chosen] if not _cands.is_empty() else _from
	var source: Piece = _piece_at(_from)
	# 1. Glow-in: ripples spread over the glow-in time; the source pad glows up.
	var ripples: int = maxi(config.glow_in_ripples, 1)
	while _next_ripple < ripples and t >= glow_in * float(_next_ripple) / float(ripples):
		_add_wave(_from, 1.0, 1.0, config.source_color)
		_next_ripple += 1
	if source != null and t <= travel_end:
		source.glow = maxf(source.glow, clampf(t / maxf(glow_in, 0.001), 0.0, 1.0))
	# 2. Travel.
	var pos: Vector3 = _from
	var zoom: float = _zoom0
	if t >= glow_in:
		var u: float = clampf((t - glow_in) / maxf(travel_end - glow_in, 0.001), 0.0, 1.0)
		if _cands.size() <= 1:
			pos = _from.lerp(dest, _ease(u))
		else:
			var zmax: float = camera_rig.view_config.zoom_max if camera_rig != null else _zoom0
			var out_share: float = config.zoom_out_share
			var in_start: float = 1.0 - config.zoom_in_share
			if u < out_share:
				var k: float = _ease(u / out_share)
				pos = _from.lerp(_overview, k)
				zoom = lerpf(_zoom0, zmax, k)
			elif u < in_start:
				pos = _overview
				zoom = zmax
			else:
				var k: float = _ease((u - in_start) / maxf(config.zoom_in_share, 0.001))
				pos = _overview.lerp(dest, k)
				zoom = lerpf(zmax, _zoom0, k)
			_step_pings(t, glow_in + (travel_end - glow_in) * in_start)
	if t >= travel_end:
		pos = dest
		zoom = _zoom0
	_max_zoom_seen = maxf(_max_zoom_seen, zoom)
	if camera_rig != null:
		camera_rig.override_view(pos, zoom)
	# 3. Arrival: ripples spread over the arrival time, area and strength x the candidate count.
	if _arrived:
		_step_arrival(t)


## Arrival ripples (area and strength x the candidate count) on the receiving pad, which glows up. They may run on
## after the trip has finished (_process keeps going while waves live).
func _step_arrival(t: float) -> void:
	var dest: Vector3 = _cands[_chosen] if not _cands.is_empty() else _from
	var ripples: int = maxi(config.arrival_ripples, 1)
	while _next_arrival_ripple < ripples and t >= _arrival_at + config.arrival_ripple_spacing * float(_next_arrival_ripple):
		_add_wave(dest, _arrival_scale, _arrival_scale, config.arrival_color)
		_next_arrival_ripple += 1
	var target: Piece = _piece_at(dest)
	if target != null and _next_arrival_ripple < ripples:
		target.glow = maxf(target.glow, _arrival_scale)


## Half-strength pings over the candidates, back and forth (0, 1, 2, 1, 0, 1 ...), until the zoom-in starts.
func _step_pings(t: float, until: float) -> void:
	var n: int = _cands.size()
	while t >= _next_ping_at and _next_ping_at < until:
		var period: int = maxi(2 * (n - 1), 1)
		var p: int = _ping_step % period
		var index: int = p if p < n else period - p
		_add_wave(_cands[index], 1.0, config.ping_strength, config.ping_color)
		var piece: Piece = _piece_at(_cands[index])
		if piece != null:
			piece.glow = maxf(piece.glow, config.ping_strength)
		_ping_step += 1
		_next_ping_at += maxf(config.ping_interval, 0.02)


## Smooth ease in / out (accelerate, then decelerate).
static func _ease(u: float) -> float:
	return u * u * u * (u * (u * 6.0 - 15.0) + 10.0)


# --- Waves and glows ------------------------------------------------------------------------------------------------

func _add_wave(centre: Vector3, scale_value: float, strength: float, color: Color) -> void:
	var w := Wave.new()
	w.centre = Vector2(centre.x, centre.z)
	w.born = _clock
	w.scale = scale_value
	w.strength = strength
	w.color = color
	if _waves.size() >= MAX_WAVES:
		_waves.remove_at(0)
	_waves.append(w)
	set_process(true)


func _push_waves() -> void:
	var count: int = 0
	var i: int = 0
	while i < _waves.size():
		var w: Wave = _waves[i]
		var age: float = _clock - w.born
		var root_scale: float = sqrt(w.scale)
		var life: float = config.wave_life * root_scale
		if age >= life:
			_waves.remove_at(i)
			continue
		var fade: float = 1.0 - age / life
		var radius: float = config.wave_speed * age
		var band: float = config.wave_band * root_scale
		_geo[count] = Vector4(w.centre.x, w.centre.y, radius, band)
		var k: float = config.wave_strength * w.strength * fade * fade
		_col[count] = Vector4(w.color.r, w.color.g, w.color.b, k)
		count += 1
		i += 1
	if surface_material == null:
		return
	surface_material.set_shader_parameter(&"wave_count", count)
	if count > 0:
		surface_material.set_shader_parameter(&"wave_geo", _geo)
		surface_material.set_shader_parameter(&"wave_col", _col)
		surface_material.set_shader_parameter(&"wave_style", Vector4(config.rainbow_spatial, config.rainbow_speed,
				config.wave_rainbow, config.wave_density))


func _step_glows(delta: float) -> void:
	for piece in _pieces:
		if piece.glow <= 0.0:
			continue
		piece.glow = maxf(piece.glow - config.glow_decay * delta, 0.0)
		_apply_look(piece)


func _any_glow() -> bool:
	for piece in _pieces:
		if piece.glow > GLOW_EPSILON:
			return true
	return false


func _piece_at(world: Vector3) -> Piece:
	if map_loader == null:
		return null
	var index: int = map_loader.data.teleport_at_centre(map_loader.world_to_cell(world))
	return _pad_pieces[index] if index >= 0 and index < _pad_pieces.size() else null


# --- Pad look -------------------------------------------------------------------------------------------------------

func _make_pad(pad: TeleportPad) -> Piece:
	var piece := Piece.new()
	piece.pad = pad
	piece.root = _make_root(pad, "Teleport")
	piece.frame = _make_flat(pad.rect.size.x, "\n".join(config.frame_lines), _columns(config.frame_lines))
	piece.root.add_child(piece.frame)
	var rune := Label3D.new()
	rune.name = "Rune"
	rune.font = _font
	rune.font_size = config.font_size
	rune.text = pad.channel
	rune.pixel_size = config.rune_height / maxf(_font.get_height(config.font_size), 1.0)
	rune.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rune.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	rune.position = Vector3(0.0, config.rune_lift, 0.0)
	rune.outline_size = config.outline_size
	rune.render_priority = 2
	rune.outline_render_priority = 1
	rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.root.add_child(rune)
	piece.rune = rune
	return piece


func _make_broken(pad: TeleportPad) -> Piece:
	var piece := Piece.new()
	piece.pad = pad
	piece.root = _make_root(pad, "BrokenTeleport")
	var per: int = maxi(config.broken_glyphs_per_cell, 1)
	var chars: String = config.broken_chars if config.broken_chars != "" else "T"
	var lines := PackedStringArray()
	var r: Rect2i = pad.rect
	for row in r.size.y * per:
		var line: String = ""
		for col in r.size.x * per:
			var cell := r.position + Vector2i(col / per, row / per)
			if pad.cells.has(cell):
				# Static per-glyph pick from the cell position (no randomness: the same map draws the same cracks).
				var h: int = absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ (col * 83492791) ^ (row * 2654435))
				line += chars[h % chars.length()]
			else:
				line += SPACE
		lines.append(line)
	piece.frame = _make_flat(r.size.x, "\n".join(lines), r.size.x * per)
	piece.root.add_child(piece.frame)
	return piece


func _make_root(pad: TeleportPad, prefix: String) -> Node3D:
	var root := Node3D.new()
	root.name = "%s_%d_%d" % [prefix, pad.rect.position.x, pad.rect.position.y]
	add_child(root)
	root.position = map_loader.rect_to_world(pad.rect)
	root.visible = false
	return root


## A label lying flat on the floor, `cells_wide` cells wide, `columns` glyphs per line, rows at the same pitch.
func _make_flat(cells_wide: int, text: String, columns: int) -> Label3D:
	var label := Label3D.new()
	label.name = "Frame"
	label.font = _font
	label.font_size = config.font_size
	var glyph: float = _font.get_char_size("M".unicode_at(0), config.font_size).x
	if glyph <= 0.0:
		glyph = config.font_size * GLYPH_ASPECT_FALLBACK
	var height: float = _font.get_height(config.font_size)
	label.pixel_size = map_loader.world_config.cell_size * float(cells_wide) / maxf(float(columns) * glyph, 1.0)
	# Square pitch: rows as far apart as columns.
	label.line_spacing = glyph - height
	label.autowrap_trim_flags = 0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	label.position = Vector3(0.0, config.frame_lift, 0.0)
	label.outline_size = config.outline_size
	label.render_priority = 1
	label.outline_render_priority = 0
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.text = text
	return label


static func _columns(lines: PackedStringArray) -> int:
	var cols: int = 0
	for line in lines:
		cols = maxi(cols, line.length())
	return cols


func _footprint_state(rect: Rect2i) -> int:
	if map_reveal == null:
		return MapReveal.CellState.SEEN
	var best: int = MapReveal.CellState.HIDDEN
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			best = maxi(best, map_reveal.state_of(Vector2i(x, y)))
	return best


## A pad was destroyed or restored (task-073): a destroyed pad shows cracks over its ring instead of its frame and rune.
func _refresh_pad(rect: Rect2i) -> void:
	for piece in _pad_pieces:
		if piece.pad.rect != rect:
			continue
		if piece.cracks == null:
			var cracked: Piece = _make_broken(piece.pad)
			piece.cracks = cracked.frame
			piece.cracks.get_parent().remove_child(piece.cracks)
			cracked.root.free()
			piece.cracks.name = "Cracks"
			piece.root.add_child(piece.cracks)
		piece.glow = 0.0
		_apply_look(piece)


func _apply_look(piece: Piece) -> void:
	var glowing: bool = piece.glow > FORCE_SHOW_GLOW
	piece.root.visible = piece.state != MapReveal.CellState.HIDDEN or glowing
	if not piece.root.visible:
		return
	var wrecked: bool = piece.rune != null and piece.pad.destroyed
	if piece.cracks != null:
		piece.cracks.visible = wrecked
		piece.frame.visible = not wrecked
		piece.rune.visible = not wrecked
	if wrecked:
		var t: Color = config.memory_tint if piece.state == MapReveal.CellState.MEMORY else Color.WHITE
		piece.cracks.modulate = config.broken_color * t
		piece.cracks.outline_modulate = config.outline_color * Color(1.0, 1.0, 1.0, t.a)
		return
	var tint: Color = Color.WHITE if piece.state == MapReveal.CellState.SEEN or glowing else config.memory_tint
	var g: float = clampf(piece.glow, 0.0, 1.0)
	var outline: Color = config.outline_color * Color(1.0, 1.0, 1.0, tint.a)
	if piece.rune == null:
		piece.frame.modulate = config.broken_color * tint
		piece.frame.outline_modulate = outline
		return
	piece.frame.modulate = config.frame_color.lerp(config.frame_glow_color, g) * tint
	piece.frame.outline_modulate = outline.lerp(config.frame_color, g * 0.6)
	piece.rune.modulate = config.rune_color.lerp(config.rune_glow_color, g) * tint
	piece.rune.outline_modulate = outline.lerp(config.rune_color, g)
	piece.rune.scale = Vector3.ONE * (1.0 + config.rune_glow_scale * minf(piece.glow, 2.0) * 0.5)
