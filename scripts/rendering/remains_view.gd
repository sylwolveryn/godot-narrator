class_name RemainsView
extends Node3D
## Draws the enemy remains (task-076) in ONE MultiMesh of glyph billboards (GlyphBillboards):
##  - diamonds: a bobbing ◆ that glints now and then (brighter, with a sparkle glyph beside it); a fresh diamond flies
##    from the destroyed enemy to its cell on an arc (the burst, SignalBus.diamonds_spawned).
##  - black holes: a dark core glyph with rings of glyphs turning around it (alternating directions, breathing in and
##    out) on the floor plane; a fresh hole grows in (SignalBus.black_hole_formed).
## Only things on cells SEEN this run are drawn (MapReveal). Reads EnemyRemains; never writes data.

@export var config: RemainsConfig
@export var remains: EnemyRemains
@export var map_loader: MapLoader
@export var map_reveal: MapReveal

var _glyphs: GlyphBillboards
var _clock: float = 0.0
## Diamond flights: cell -> [from_position, start clock].
var _flights: Dictionary[Vector2i, Array] = {}
## Black hole formation: cell -> start clock.
var _forming: Dictionary[Vector2i, float] = {}


func _ready() -> void:
	if config == null:
		config = RemainsConfig.new()
	var chars: String = config.diamond_glyph + config.sparkle_glyph + config.core_glyph
	for s in config.ring_chars:
		chars += s
	var per_hole: int = 2
	for c in config.ring_counts:
		per_hole += c
	_glyphs = GlyphBillboards.new()
	_glyphs.name = "RemainsGlyphs"
	add_child(_glyphs)
	_glyphs.setup(chars, config.glyph_font_names, config.glyph_tile_px, config.glyph_font_px,
			config.max_diamonds * 2 + config.max_holes * per_hole, Color(1.0, 1.0, 1.0))
	SignalBus.diamonds_spawned.connect(_on_diamonds_spawned)
	SignalBus.black_hole_formed.connect(func(cell: Vector2i, _w: Vector3) -> void: _forming[cell] = _clock)
	SignalBus.remains_reset.connect(func() -> void:
		_flights.clear()
		_forming.clear())


## Glyph quads drawn in the last frame (tests).
func drawn() -> int:
	return _glyphs.drawn


func _on_diamonds_spawned(from_position: Vector3, cells: Array[Vector2i]) -> void:
	for c in cells:
		_flights[c] = [from_position, _clock]


func _process(delta: float) -> void:
	if remains == null or map_loader == null:
		return
	_clock += delta
	var cam: Camera3D = get_viewport().get_camera_3d()
	var right: Vector3 = cam.global_basis.x if cam != null else Vector3.RIGHT
	_glyphs.begin()
	var drawn_holes: int = 0
	for cell in remains.holes():
		if drawn_holes >= config.max_holes:
			break
		if _seen(cell):
			_draw_hole(cell)
			drawn_holes += 1
	for cell: Vector2i in remains.diamonds():
		if _seen(cell) or _flights.has(cell):
			_draw_diamond(cell, right)
	_glyphs.end()


func _seen(cell: Vector2i) -> bool:
	return map_reveal == null or map_reveal.state_of(cell) == MapReveal.CellState.SEEN


func _draw_hole(cell: Vector2i) -> void:
	var centre: Vector3 = map_loader.cell_to_world(cell)
	var grow: float = 1.0
	if _forming.has(cell):
		grow = clampf((_clock - _forming[cell]) / maxf(config.form_seconds, 0.001), 0.0, 1.0)
		if grow >= 1.0:
			_forming.erase(cell)
		grow = ease(grow, 0.4)
	var phase: float = float(cell.x * 7 + cell.y * 13)
	_glyphs.put(centre + Vector3.UP * config.core_hover, config.core_shade_size * grow, config.core_color, config.core_shade_alpha,
			_glyphs.column(config.core_glyph), 0.0)
	_glyphs.put(centre + Vector3.UP * config.core_hover, config.core_size * grow, config.core_color, 1.0, _glyphs.column(config.core_glyph), 0.0)
	var pulse: float = 1.0 + sin(_clock * TAU * config.ring_pulse_hz + phase) * config.ring_pulse
	for r in config.ring_counts.size():
		var n: int = config.ring_counts[r]
		var radius: float = config.ring_radii[r] * pulse * grow if r < config.ring_radii.size() else 0.0
		var speed: float = deg_to_rad(config.ring_speeds[r] if r < config.ring_speeds.size() else 0.0)
		var chars: String = config.ring_chars[r] if r < config.ring_chars.size() and config.ring_chars[r] != "" else "."
		var color: Color = config.ring_colors[r] if r < config.ring_colors.size() else Color.WHITE
		var size: float = config.ring_glyph_size * (1.0 - config.ring_size_falloff * r) * grow
		for k in n:
			var angle: float = phase + TAU * float(k) / float(maxi(n, 1)) + speed * _clock
			var pos: Vector3 = centre + Vector3(cos(angle) * radius, config.ring_hover, sin(angle) * radius)
			_glyphs.put(pos, size, color, 1.0, _glyphs.column(chars[k % chars.length()]), 0.5)


func _draw_diamond(cell: Vector2i, right: Vector3) -> void:
	var phase: float = float(cell.x * 3 + cell.y * 5) * 0.37
	var rest: Vector3 = map_loader.cell_to_world(cell) + Vector3.UP * (config.diamond_hover + sin(_clock * TAU * config.diamond_bob_hz + phase) * config.diamond_bob)
	var pos: Vector3 = rest
	if _flights.has(cell):
		var flight: Array = _flights[cell]
		var t: float = clampf((_clock - float(flight[1])) / maxf(config.burst_seconds, 0.001), 0.0, 1.0)
		var from: Vector3 = (flight[0] as Vector3) + Vector3.UP * config.diamond_hover
		pos = from.lerp(rest, ease(t, 0.6)) + Vector3.UP * (4.0 * t * (1.0 - t) * config.burst_height)
		if t >= 1.0:
			_flights.erase(cell)
	var g: float = fposmod(_clock + phase * config.glint_period, maxf(config.glint_period, 0.001))
	var glint: float = 1.0 - clampf(g / maxf(config.glint_seconds, 0.001), 0.0, 1.0) if g < config.glint_seconds else 0.0
	var color: Color = config.diamond_color.lerp(config.sparkle_color, glint * 0.6)
	_glyphs.put(pos, config.diamond_size * (1.0 + 0.15 * glint), color, 1.0, _glyphs.column(config.diamond_glyph), 0.35 + 0.65 * glint)
	if glint > 0.0:
		_glyphs.put(pos + right * config.diamond_size * 0.9 + Vector3.UP * config.diamond_size * 0.7, config.sparkle_size * glint,
				config.sparkle_color, glint, _glyphs.column(config.sparkle_glyph), 1.0)
