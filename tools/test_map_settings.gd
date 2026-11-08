extends SceneTree
## Headless test of the per-map visibility settings (task-069): MapSettings.resolve (no row = exactly the configs,
## negative numbers keep the defaults); in the main scene a map without a map_settings row (m1) gets exactly the config
## uniforms and reveal rules of before; the m3_dirt row (bundled seed) reveals every drawn cell as seen at run start with
## fog and darkness off; a DB reload (GameDatabase.tables_loaded) re-applies changed rows.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_map_settings.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "map_settings"
const M1 := "res://data/maps/m1_awakening.txt"
const M3 := "res://data/maps/m3_dirt.txt"
const PHASE_PLAYING := 1
const CELL_HIDDEN := 0
const CELL_SEEN := 2
const EPS := 0.0001

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	_check_resolve()
	await _check_scene()
	if _failures.is_empty():
		print("PASS test_map_settings")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_map_settings")
		quit(1)


func _check_resolve() -> void:
	var rc := RevealConfig.new()
	var look := GlyphWorldConfig.new()
	var s: MapSettings = MapSettings.resolve({}, rc, look)
	_check(not s.reveal_all and s.fog_enabled and s.darkness_enabled, "no row: no reveal_all, fog and darkness on")
	_check(s.reveal_radius == rc.reveal_radius and s.line_of_sight == rc.line_of_sight, "no row: reveal rules of RevealConfig")
	_check(s.player_light_radius == look.player_light_radius and s.ambient_level == look.ambient_level and s.ambient_color == look.ambient_color, "no row: light of GlyphWorldConfig")
	s = MapSettings.resolve({"map_id": "x", "reveal_radius": -1.0, "player_light_radius": 7.0, "line_of_sight": false}, rc, look)
	_check(s.reveal_radius == rc.reveal_radius, "negative radius keeps the default")
	_check(s.player_light_radius == 7.0 and not s.line_of_sight, "row values win")
	s = MapSettings.resolve({"darkness_enabled": false}, rc, look)
	_check(s.ambient_level == look.full_light_ambient and s.ambient_color == look.full_light_color, "no darkness = full light")
	s = MapSettings.resolve({"darkness_enabled": false, "ambient_level": 0.4}, rc, look)
	_check(absf(s.ambient_level - 0.4) < EPS, "ambient_level column wins over darkness off")


func _fast_intro() -> IntroConfig:
	var cfg := IntroConfig.new()
	cfg.black_hold = 0.05
	cfg.wave_fade_in = 0.05
	cfg.wave_hold = 0.05
	cfg.reveal_duration = 0.05
	return cfg


func _param(material: ShaderMaterial, name: StringName) -> Variant:
	return material.get_shader_parameter(name)


func _close(a: Variant, b: Variant) -> bool:
	if a is float or b is float:
		return absf(float(a) - float(b)) < EPS
	if a is Vector3 and b is Vector3:
		return (a as Vector3).is_equal_approx(b)
	return a == b


func _check_scene() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var save_path: String = Support.isolate_save(main, SAVE_TAG)
	main.get_node("IntroSequence").set("config", _fast_intro())
	var loader: MapLoader = main.get_node("World/MapLoader")
	loader.map_path = M1
	loader.use_cmdline_map = false
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 3.0:
		await create_timer(0.1).timeout
		guard += 0.1
	await create_timer(0.2).timeout
	var resolver = main.get_node("MapSettingsResolver")
	var reveal = main.get_node("MapReveal")
	var view = main.get_node("GlyphWorldView")
	var db = main.get_node("GameDatabase")
	var look: GlyphWorldConfig = view.config
	var mat: ShaderMaterial = view.material

	# --- m1: no row, everything as before. ---
	_check(resolver.current_row().is_empty(), "m1 has no map_settings row")
	_check(not db.rows(MapSettings.TABLE).is_empty(), "the bundled seed holds map_settings rows")
	var expected: Dictionary = {
		&"ambient_level": look.ambient_level, &"ambient_color": Vector3(look.ambient_color.r, look.ambient_color.g, look.ambient_color.b),
		&"fog_strength": look.fog_strength, &"fog_start": look.fog_start, &"depth_ambient_min": look.depth_ambient_min,
		&"depth_near": look.depth_near, &"depth_far": look.depth_far,
		&"memory_dim": look.memory_dim, &"memory_saturation": look.memory_saturation,
		&"memory_tint": Vector3(look.memory_tint.r, look.memory_tint.g, look.memory_tint.b),
		&"memory_density": look.memory_density, &"memory_dropout": look.memory_dropout,
		&"memory_emit": look.memory_emit, &"memory_floor": look.memory_floor,
	}
	for key: StringName in expected:
		_check(_close(_param(mat, key), expected[key]), "m1 uniform %s = %s, config %s" % [key, _param(mat, key), expected[key]])
	_check(view.map_settings.player_light_radius == look.player_light_radius, "m1 player light radius from the config")
	var light_pos: PackedVector4Array = _param(mat, &"light_pos")
	_check(absf(light_pos[0].w - look.player_light_radius) < EPS, "m1 player light radius in the shader")
	_check(reveal.map_settings.reveal_radius == reveal.config.reveal_radius and reveal.map_settings.line_of_sight == reveal.config.line_of_sight, "m1 reveal rules from RevealConfig")
	var hidden: int = 0
	for cell: Vector2i in loader.drawn_cells:
		if reveal.state_of(cell) == CELL_HIDDEN:
			hidden += 1
	_check(hidden > loader.drawn_cells.size() / 2, "m1 starts mostly hidden (%d of %d hidden)" % [hidden, loader.drawn_cells.size()])

	# --- m3_dirt: reveal_all, no fog, no darkness. ---
	loader.build(loader.load_file(M3))
	await process_frame
	_check(loader.map_id == &"m3_dirt", "map id m3_dirt")
	_check(not resolver.current_row().is_empty(), "m3_dirt has a row")
	_check(reveal.map_settings.reveal_all, "m3 reveal_all")
	var unseen: int = 0
	var not_live: int = 0
	for cell: Vector2i in loader.drawn_cells:
		if reveal.state_of(cell) != CELL_SEEN:
			unseen += 1
		var m: Color = reveal.mask_at(cell)
		if m.g < 1.0 or m.r <= 0.0:
			not_live += 1
	_check(unseen == 0, "m3: every drawn cell seen at run start (%d not)" % unseen)
	_check(not_live == 0, "m3: every drawn cell has the live look in the mask (%d not)" % not_live)
	_check(_close(_param(mat, &"fog_strength"), 0.0) and _close(_param(mat, &"depth_ambient_min"), 1.0), "m3: no fog")
	_check(_close(_param(mat, &"ambient_level"), look.full_light_ambient), "m3: full light ambient")
	_check(_close(_param(mat, &"memory_dim"), 1.0) and _close(_param(mat, &"memory_dropout"), 0.0), "m3: no memory dimming")
	# A new run on m3 is revealed again at once.
	reveal.begin_run()
	_check(reveal.state_of(loader.data.spawn_cell + Vector2i(30, 20)) == CELL_SEEN or not loader.is_drawn(loader.data.spawn_cell + Vector2i(30, 20)), "m3: far cell seen after begin_run")

	# --- DB reload re-applies: fog back on for m3, a radius row for m1. ---
	var rows: Array = (db.tables[MapSettings.TABLE] as Array).duplicate(true)
	for row: Dictionary in rows:
		if row["map_id"] == "m3_dirt":
			row["fog_enabled"] = true
	rows.append({"map_id": "m1_awakening", "reveal_all": false, "fog_enabled": true, "darkness_enabled": true,
			"reveal_radius": 2.0, "line_of_sight": true, "player_light_radius": 6.0, "ambient_level": -1.0})
	db.tables[MapSettings.TABLE] = rows
	db.tables_loaded.emit(db.tables)
	_check(_close(_param(mat, &"fog_strength"), look.fog_strength), "reload: m3 fog back on")
	loader.build(loader.load_file(M1))
	await process_frame
	_check(reveal.map_settings.reveal_radius == 2.0, "reload: m1 row radius applies on the next map load")
	_check(view.map_settings.player_light_radius == 6.0, "reload: m1 row light radius")

	main.queue_free()
	await process_frame
	Support.remove_file(save_path)
