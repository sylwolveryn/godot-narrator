class_name EnemyView
extends Node3D
## Draws the enemies (task-075): every enemy is a small ASCII glyph creature (EnemyDef.glyphs: a body glyph plus
## satellites - legs, eyes, an orbiting tail - in its own colours) made of camera-facing glyph quads, ALL enemies in one
## MultiMesh (GlyphBillboards). Idle animation: the body bobs, the satellites wiggle (crawler legs scuttle while it
## moves) or orbit. An enemy is drawn only while its cell is SEEN this run (MapReveal; fades in / out over
## EnemyConfig.reveal_fade). A destroyed enemy bursts into fragments of its glyphs (SignalBus.enemy_destroyed). Reads
## EnemySystem; never writes data.

@export var config: EnemyConfig
@export var enemies: EnemySystem
@export var map_loader: MapLoader
@export var map_reveal: MapReveal

var _glyphs: GlyphBillboards
var _clock: float = 0.0
## Reveal fade per enemy (0 hidden .. 1 shown).
var _vis := PackedFloat32Array()
## Destruction bursts: [origin, color, accent, glyphs (String), started (clock), seed].
var _puffs: Array[Array] = []


func _ready() -> void:
	if config == null:
		config = EnemyConfig.new()
	var chars: String = ""
	for d in config.defs:
		if d != null:
			chars += d.glyphs
	_glyphs = GlyphBillboards.new()
	_glyphs.name = "EnemyGlyphs"
	add_child(_glyphs)
	_glyphs.setup(chars, config.glyph_font_names, config.glyph_tile_px, config.glyph_font_px, config.max_glyphs, config.rim_color)
	SignalBus.enemies_reset.connect(_on_enemies_reset)
	SignalBus.enemy_destroyed.connect(_on_enemy_destroyed)
	if enemies != null:
		_on_enemies_reset(enemies.count())


## Glyph quads drawn in the last frame (tests).
func drawn() -> int:
	return _glyphs.drawn


## Reveal fade of enemy i (tests).
func visibility_of(i: int) -> float:
	return _vis[i] if i < _vis.size() else 0.0


func _on_enemies_reset(n: int) -> void:
	_vis.resize(n)
	_vis.fill(0.0)
	_puffs.clear()


func _on_enemy_destroyed(kind: StringName, _cell: Vector2i, world_position: Vector3, _cause: StringName) -> void:
	var def: EnemyDef = enemies.resolved.def_for(kind) if enemies != null else config.def_for(kind)
	if def == null:
		return
	_puffs.append([world_position + Vector3.UP * def.hover, def.color, def.accent, def.glyphs, _clock, randf() * TAU, def.body_size])


func _process(delta: float) -> void:
	if enemies == null:
		return
	_clock += delta
	var cam: Camera3D = get_viewport().get_camera_3d()
	var right: Vector3 = cam.global_basis.x if cam != null else Vector3.RIGHT
	var up: Vector3 = cam.global_basis.y if cam != null else Vector3.UP
	var rate: float = delta / maxf(config.reveal_fade, 0.001)
	_glyphs.begin()
	for i in mini(enemies.count(), _vis.size()):
		var shown: bool = enemies.is_alive(i) and _is_seen(i)
		_vis[i] = move_toward(_vis[i], 1.0 if shown else 0.0, rate)
		if _vis[i] > 0.0 and enemies.is_alive(i):
			_draw_enemy(i, right, up)
	_draw_puffs(right, up)
	_glyphs.end()


func _is_seen(i: int) -> bool:
	if map_reveal == null:
		return true
	var a: Vector2i = enemies.cell_of(i)
	var b: Vector2i = enemies.next_of(i)
	return map_reveal.state_of(a) == MapReveal.CellState.SEEN or map_reveal.state_of(b) == MapReveal.CellState.SEEN


func _draw_enemy(i: int, right: Vector3, up: Vector3) -> void:
	var def: EnemyDef = enemies.def_of(i)
	var phase: float = float(i) * 1.7
	var moving: bool = enemies.next_of(i) != enemies.cell_of(i)
	var a: float = _vis[i]
	var bob: float = sin(_clock * TAU * def.bob_hz + phase) * def.bob_amount
	var centre: Vector3 = enemies.position_of(i) + Vector3.UP * (def.hover + bob)
	var glyphs: String = def.glyphs
	if glyphs.is_empty():
		return
	_glyphs.put(centre, def.body_size, def.color, a, _glyphs.column(glyphs[0]), def.glow)
	var sats: int = glyphs.length() - 1
	var wiggle_speed: float = def.wiggle_hz * (1.0 if moving else 0.35)
	for k in sats:
		var angle: float = deg_to_rad(def.satellite_start_degrees + def.satellite_step_degrees * k + def.orbit_degrees_per_second * _clock)
		var w: float = sin(_clock * TAU * wiggle_speed + phase + k * PI) * def.wiggle_amount
		var off: Vector3 = (right * cos(angle) + up * sin(angle)) * (def.satellite_radius + w)
		_glyphs.put(centre + off, def.body_size * def.satellite_scale, def.accent, a, _glyphs.column(glyphs[k + 1]), def.glow)


func _draw_puffs(right: Vector3, up: Vector3) -> void:
	var life: float = maxf(config.puff_seconds, 0.001)
	var k: int = _puffs.size() - 1
	while k >= 0:
		var puff: Array = _puffs[k]
		var age: float = _clock - float(puff[4])
		if age >= life:
			_puffs.remove_at(k)
			k -= 1
			continue
		var t: float = age / life
		var glyphs: String = puff[3]
		var origin: Vector3 = puff[0]
		for j in config.puff_count:
			var angle: float = float(puff[5]) + TAU * float(j) / float(maxi(config.puff_count, 1))
			var dir: Vector3 = right * cos(angle) + up * sin(angle)
			var pos: Vector3 = origin + dir * config.puff_speed * age + Vector3.UP * (config.puff_lift * age - 2.0 * config.puff_lift * age * age)
			var col: Color = puff[1] if j % 2 == 0 else puff[2]
			var ch: String = glyphs[j % glyphs.length()]
			_glyphs.put(pos, float(puff[6]) * (1.0 - 0.6 * t), col, 1.0 - t, _glyphs.column(ch), 0.6)
		k -= 1
