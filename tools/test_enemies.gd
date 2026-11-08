extends SceneTree
## Headless test of the enemies (task-075) on small hand-made maps:
##  - legend: L R H W parse to enemy spawns on floor (no warnings);
##  - crawler L / R: keeps a wall beside it at every step and loops a room clockwise (L) / counter-clockwise (R) on
##    screen; from open floor it goes straight until it meets a wall; circles a pillar it starts next to;
##  - hunter: reaches the player around a wall, never stands on dirt (and eats none); out of its search window it
##    does not home in;
##  - wanderer: only ever on free cells, covers the room, re-rolls; enemies never share a cell;
##  - contact: each kind ends the run with its cause (enemy_crawler / enemy_hunter / enemy_wanderer), the narrator maps
##    them to DEATH_BY_ENEMY; a non-lethal kind (DB override) does not;
##  - the DB table enemy_def overrides per-kind numbers;
##  - in the main scene: a cannon ball destroys an enemy (Destructibles kind "enemy", cause cannon), touching a hunter
##    ends the run (cause enemy_hunter) and the next run brings every enemy back.
## The movement checks drive EnemySystem by hand (fixed 1/60 s steps) on a bare MapLoader.
## Usage: godot --headless --max-fps 30 --path . -s tools/test_enemies.gd

const Support := preload("res://tools/test_support.gd")
const SAVE_TAG := "enemies"
const LEGEND := "res://resources/config/map_legend.tres"
const WORLD := "res://resources/config/world_config.tres"
const ENEMY_CONFIG := "res://resources/config/enemy_config.tres"
const NARRATOR_CONFIG := "res://resources/narration/narrator_config.tres"
const MAP_PATH := "user://test_enemies_map.txt"
## Scripts that use the SignalBus autoload are loaded at runtime (a SceneTree script compiles before autoloads exist).
const ENEMY_SYSTEM := "res://scripts/world/enemy_system.gd"
const KIND_ENEMY: StringName = &"enemy"
const CAUSE_CANNON: StringName = &"cannon"
const DT := 1.0 / 60.0
const PHASE_PLAYING := 1

const ROOM := [
	"##########",
	"#........#",
	"#........#",
	"#........#",
	"#........#",
	"#........#",
	"##########",
]
const PILLAR_ROOM := [
	"############",
	"#..........#",
	"#..........#",
	"#....##....#",
	"#....##....#",
	"#..........#",
	"#..........#",
	"############",
]
## Hunter at (2, 2), player at (9, 2); a wall column x = 5 with the only gap at the bottom row, dirt above the wall's
## top so the direct way would be through dirt.
const HUNT := [
	"############",
	"#....D.....#",
	"#....#.....#",
	"#....#.....#",
	"#....#.....#",
	"#..........#",
	"############",
]
const MAZE := [
	"###############",
	"#.....#.......#",
	"#.###.#.#####.#",
	"#.#.....#...#.#",
	"#.#.###.#.#.#.#",
	"#...#.....#...#",
	"###############",
]

var _failures: PackedStringArray = []
var _done: bool = false
var _ended: Array[StringName] = []
var _destroyed: Array[Array] = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run() -> void:
	var bus: Node = root.get_node("SignalBus")
	bus.connect("run_end_requested", func(c: StringName) -> void: _ended.append(c))
	bus.connect("destructible_destroyed", func(k: StringName, r: Rect2i, _w: Vector3, c: StringName) -> void: _destroyed.append([k, r, c]))
	_check_legend()
	_check_crawler_loop("L", 1)
	_check_crawler_loop("R", -1)
	_check_crawler_open()
	_check_crawler_pillar()
	_check_hunter()
	_check_wanderer()
	_check_contact()
	_check_db_override()
	await _check_scene()
	_check(_done, "the scene checks ran to the end")
	if _failures.is_empty():
		print("PASS test_enemies")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("FAIL test_enemies")
		quit(1)


# --------------------------------------------------------------------------- helpers

## A bare world: MapLoader (built from `lines` with `extra` put at cells) and an EnemySystem stepped by hand.
func _world(lines: Array, extra: Dictionary = {}, player_cell: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var rows: PackedStringArray = PackedStringArray(lines)
	for cell: Vector2i in extra:
		var row: String = rows[cell.y]
		rows[cell.y] = row.substr(0, cell.x) + String(extra[cell]) + row.substr(cell.x + 1)
	var loader := MapLoader.new()
	loader.legend = load(LEGEND) as MapLegend
	loader.world_config = load(WORLD) as WorldConfig
	loader.auto_load = false
	loader.use_cmdline_map = false
	root.add_child(loader)
	var map: MapData = loader.parse_text("\n".join(rows))
	loader.build(map)
	var player: Node3D = null
	if player_cell.x >= 0:
		player = Node3D.new()
		root.add_child(player)
		player.global_position = loader.cell_to_world(player_cell)
	var sys: Node = (load(ENEMY_SYSTEM) as GDScript).new()
	sys.config = load(ENEMY_CONFIG) as EnemyConfig
	sys.map_loader = loader
	sys.player = player
	sys.player_config = PlayerConfig.new()
	root.add_child(sys)
	sys.set_physics_process(false)
	sys.rng.seed = 1234
	return {"loader": loader, "sys": sys, "map": map, "player": player}


func _free(w: Dictionary) -> void:
	(w["sys"] as Node).free()
	(w["loader"] as Node).free()
	if w["player"] != null:
		(w["player"] as Node).free()


## Steps the system `frames` times; returns the cells entered by enemy `i` (in order, the start cell first).
func _trace(sys: Node, i: int, frames: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [sys.cell_of(i)]
	for f in frames:
		sys._physics_process(DT)
		if sys.is_alive(i) and sys.cell_of(i) != out[out.size() - 1]:
			out.append(sys.cell_of(i))
	return out


func _blocked_near(map: MapData, cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var t: StringName = map.type_at(cell + Vector2i(dx, dy))
			if (dx != 0 or dy != 0) and t != MapLegend.FLOOR and t != MapLegend.SPAWN:
				return true
	return false


## Signed area of a closed cell loop (shoelace, y down): > 0 = clockwise on screen.
func _signed_area(cells: Array[Vector2i]) -> float:
	var a: float = 0.0
	for k in cells.size():
		var p: Vector2i = cells[k]
		var q: Vector2i = cells[(k + 1) % cells.size()]
		a += float(p.x * q.y - q.x * p.y)
	return a * 0.5


func _frames_for_cells(sys: Node, i: int, cells: int) -> int:
	return int(ceil(float(cells) / sys.def_of(i).speed / DT)) + 2


# --------------------------------------------------------------------------- checks

func _check_legend() -> void:
	var w: Dictionary = _world(ROOM, {Vector2i(1, 1): "L", Vector2i(3, 1): "R", Vector2i(5, 3): "H", Vector2i(7, 5): "W", Vector2i(8, 1): "@"})
	var map: MapData = w["map"]
	_check(map.warnings.is_empty() and map.errors.is_empty(), "L R H W parse cleanly: %s %s" % [map.warnings, map.errors])
	_check(map.enemies.size() == 4 and map.enemy_types == ([&"crawler_left", &"crawler_right", &"hunter", &"wanderer"] as Array[StringName]), "4 enemy spawns in row order: %s" % [map.enemy_types])
	_check(map.type_at(Vector2i(1, 1)) == MapLegend.FLOOR and map.type_at(Vector2i(5, 3)) == MapLegend.FLOOR, "spawn cells are floor")
	var sys: Node = w["sys"]
	_check(sys.count() == 4 and sys.kind_of(0) == &"crawler" and sys.kind_of(2) == &"hunter" and sys.kind_of(3) == &"wanderer", "system has the 4 enemies")
	_check(sys.hand_of(0) == EnemyConfig.HAND_LEFT and sys.hand_of(1) == EnemyConfig.HAND_RIGHT, "L / R hands")
	_check(sys.is_enemy_at(Vector2i(5, 3)) and not sys.is_enemy_at(Vector2i(6, 3)), "enemies hold their cells")
	_free(w)


func _check_crawler_loop(ch: String, sign_expected: int) -> void:
	var w: Dictionary = _world(ROOM, {Vector2i(1, 3): ch, Vector2i(5, 3): "@"})
	var sys: Node = w["sys"]
	var map: MapData = w["map"]
	var perimeter: int = 2 * (8 + 5) - 4
	var cells: Array[Vector2i] = _trace(sys, 0, _frames_for_cells(sys, 0, perimeter * 3))
	var lost: int = 0
	for c in cells:
		if not _blocked_near(map, c):
			lost += 1
	_check(lost == 0, "crawler %s keeps a wall beside it (%d cells without)" % [ch, lost])
	var loop: Array[Vector2i] = cells.slice(0, perimeter)
	var distinct: Dictionary = {}
	for c in loop:
		distinct[c] = true
	_check(distinct.size() == perimeter, "crawler %s walks the whole room edge (%d of %d)" % [ch, distinct.size(), perimeter])
	_check(cells.size() > perimeter and cells[perimeter] == cells[0], "crawler %s loops back to its start" % ch)
	var area: float = _signed_area(loop)
	_check(signf(area) == sign_expected, "crawler %s loops %s (area %.1f)" % [ch, "clockwise" if sign_expected > 0 else "counter-clockwise", area])
	_free(w)


func _check_crawler_open() -> void:
	# From the middle of a big room facing east (no wall beside it): straight to the east wall, then along it.
	var big: Array = ["####################"]
	for y in 9:
		big.append("#" + ".".repeat(18) + "#")
	big.append("####################")
	var w: Dictionary = _world(big, {Vector2i(5, 5): "L", Vector2i(1, 1): "@"})
	var sys: Node = w["sys"]
	sys._dir[0] = 1
	var cells: Array[Vector2i] = _trace(sys, 0, _frames_for_cells(sys, 0, 16))
	var straight: bool = true
	for k in range(1, cells.size()):
		if cells[k].x < 18 and (cells[k].y != 5 or cells[k].x != 5 + k):
			straight = false
	_check(straight, "crawler in open floor goes straight until a wall: %s" % [cells.slice(0, 15)])
	_check(cells.has(Vector2i(18, 5)), "it reaches the east wall")
	var after: Vector2i = cells[cells.find(Vector2i(18, 5)) + 1] if cells.find(Vector2i(18, 5)) + 1 < cells.size() else Vector2i(-1, -1)
	# Left hand: the wall ahead becomes its left side by turning right (east -> south).
	_check(after == Vector2i(18, 6), "then turns away from the wall keeping it on its left side (%s)" % after)
	_free(w)


func _check_crawler_pillar() -> void:
	var w: Dictionary = _world(PILLAR_ROOM, {Vector2i(4, 3): "L", Vector2i(1, 1): "@"})
	var sys: Node = w["sys"]
	var cells: Array[Vector2i] = _trace(sys, 0, _frames_for_cells(sys, 0, 40))
	var far: int = 0
	for c in cells:
		if c.x < 4 or c.x > 7 or c.y < 2 or c.y > 5:
			far += 1
	var distinct: Dictionary = {}
	for c in cells:
		distinct[c] = true
	_check(far == 0 and distinct.size() == 12, "crawler next to a pillar circles it (%d off, %d distinct)" % [far, distinct.size()])
	_free(w)


func _check_hunter() -> void:
	var w: Dictionary = _world(HUNT, {Vector2i(2, 2): "H", Vector2i(9, 2): "@"}, Vector2i(9, 2))
	var sys: Node = w["sys"]
	var map: MapData = w["map"]
	var cells: Array[Vector2i] = _trace(sys, 0, _frames_for_cells(sys, 0, 30))
	_check(cells.has(Vector2i(9, 2)), "hunter reaches the player around the wall (%d cells: %s)" % [cells.size(), cells])
	var bad: int = 0
	for c in cells:
		if map.type_at(c) != MapLegend.FLOOR and map.type_at(c) != MapLegend.SPAWN:
			bad += 1
	_check(bad == 0, "hunter only walks free cells")
	_check(cells.has(Vector2i(5, 5)), "hunter goes through the gap at the bottom")
	_check(map.type_at(Vector2i(5, 1)) == MapLegend.DIRT, "hunter never digs")
	_check(sys.searches > 0, "hunter searched a path")
	_free(w)
	# Out of its window: the player 40 cells away is not hunted.
	var long: Array = ["#".repeat(50)]
	for y in 3:
		long.append("#" + ".".repeat(48) + "#")
	long.append("#".repeat(50))
	w = _world(long, {Vector2i(1, 2): "H", Vector2i(48, 2): "@"}, Vector2i(48, 2))
	sys = w["sys"]
	var cfg: EnemyDef = sys.def_of(0)
	var c2: Array[Vector2i] = _trace(sys, 0, 120)
	_check(cfg.search_radius < 47 and sys.searches == 0, "no search for a player outside the window (%d)" % sys.searches)
	_check(c2.size() > 1, "an idle hunter wanders")
	_free(w)


func _check_wanderer() -> void:
	var w: Dictionary = _world(MAZE, {Vector2i(1, 1): "W", Vector2i(13, 5): "W", Vector2i(7, 3): "W", Vector2i(3, 3): "@"})
	var sys: Node = w["sys"]
	var map: MapData = w["map"]
	var seen: Dictionary = {}
	var bad: int = 0
	var shared: int = 0
	for f in 3000:
		sys._physics_process(DT)
		var held: Dictionary = {}
		for i in sys.count():
			var c: Vector2i = sys.cell_of(i)
			seen[c] = true
			if map.type_at(c) != MapLegend.FLOOR and map.type_at(c) != MapLegend.SPAWN:
				bad += 1
			for cc: Vector2i in [c, sys.next_of(i)]:
				if held.has(cc) and held[cc] != i:
					shared += 1
				held[cc] = i
	_check(bad == 0, "wanderers stay on free cells (%d bad)" % bad)
	_check(shared == 0, "enemies never share a cell (%d)" % shared)
	var floor_cells: int = 0
	for y in map.height:
		for x in map.width:
			if map.type_at(Vector2i(x, y)) == MapLegend.FLOOR:
				floor_cells += 1
	_check(seen.size() * 2 > floor_cells, "wanderers roam the maze (%d of %d cells)" % [seen.size(), floor_cells])
	_free(w)


func _check_contact() -> void:
	var narrator: NarratorConfig = load(NARRATOR_CONFIG) as NarratorConfig
	for ch: String in ["L", "H", "W"]:
		_ended.clear()
		var w: Dictionary = _world(ROOM, {Vector2i(4, 3): ch, Vector2i(1, 1): "@"}, Vector2i(4, 3))
		var sys: Node = w["sys"]
		sys._physics_process(DT)
		var cause: StringName = sys.def_of(0).end_cause()
		_check(_ended == ([cause] as Array[StringName]), "contact with %s ends the run once with %s: %s" % [ch, cause, _ended])
		_check(narrator.death_events.get(cause, &"") == NarrationEvents.DEATH_BY_ENEMY, "%s maps to DEATH_BY_ENEMY" % cause)
		sys._physics_process(DT)
		_check(_ended.size() == 1, "contact fires once per run")
		_free(w)
	_check([&"enemy_crawler", &"enemy_hunter", &"enemy_wanderer"].all(func(c: StringName) -> bool: return narrator.death_events.has(c)), "all three causes mapped")
	# Far away: nothing.
	_ended.clear()
	var w2: Dictionary = _world(ROOM, {Vector2i(1, 1): "W", Vector2i(8, 5): "@"}, Vector2i(8, 5))
	(w2["sys"] as Node)._physics_process(DT)
	_check(_ended.is_empty(), "a far enemy does not kill")
	_free(w2)


func _check_db_override() -> void:
	var cfg: EnemyConfig = load(ENEMY_CONFIG) as EnemyConfig
	var tables: Dictionary = {"enemy_def": [{"kind": "hunter", "speed": 5.5, "lethal": false, "search_radius": 4, "diamonds": 7}]}
	var r: EnemyConfig = cfg.from_tables(tables)
	_check(is_equal_approx(r.def_for(&"hunter").speed, 5.5) and not r.def_for(&"hunter").lethal and r.def_for(&"hunter").search_radius == 4 and r.def_for(&"hunter").diamonds == 7, "enemy_def row overrides the hunter")
	_check(is_equal_approx(r.def_for(&"crawler").speed, cfg.def_for(&"crawler").speed), "kinds without a row keep the defaults")
	_check(is_equal_approx(cfg.def_for(&"hunter").speed, 2.6), "the base config is untouched")
	var seed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/db/seed.json"))
	var kinds: Array = []
	for row: Dictionary in (seed as Dictionary).get("enemy_def", []):
		kinds.append(row["kind"])
		var d: EnemyDef = cfg.def_for(StringName(row["kind"]))
		_check(d != null and is_equal_approx(d.speed, float(row["speed"])) and d.diamonds == int(row["diamonds"]) and d.black_hole == bool(row["black_hole"]), "seed row %s matches the config defaults" % row["kind"])
	_check(kinds.size() == 3, "seed has the three kinds: %s" % [kinds])
	# A non-lethal hunter (DB) does not kill.
	_ended.clear()
	var w: Dictionary = _world(ROOM, {Vector2i(4, 3): "H", Vector2i(1, 1): "@"}, Vector2i(4, 3))
	var sys: Node = w["sys"]
	sys._on_tables_loaded({"enemy_def": [{"kind": "hunter", "lethal": false}]})
	sys._physics_process(DT)
	_check(_ended.is_empty(), "a non-lethal enemy does not end the run")
	_free(w)


# --------------------------------------------------------------------------- main scene

func _fast_intro() -> IntroConfig:
	var cfg := IntroConfig.new()
	cfg.black_hold = 0.05
	cfg.wave_fade_in = 0.05
	cfg.wave_hold = 0.05
	cfg.reveal_duration = 0.05
	return cfg


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _check_scene() -> void:
	var lines: PackedStringArray = PackedStringArray([
		"####################",
		"#..................#",
		"#.C.......L........#",
		"#..................#",
		"#..................#",
		"#..........@.......#",
		"#..................#",
		"#................H.#",
		"####################",
	])
	var f := FileAccess.open(MAP_PATH, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	Support.isolate_save(main, SAVE_TAG)
	main.get_node("IntroSequence").set("config", _fast_intro())
	var run_cfg := RunConfig.new()
	run_cfg.restart_delay = 0.3
	run_cfg.intro_on_restart = false
	main.get_node("RunManager").set("config", run_cfg)
	var loader: MapLoader = main.get_node("World/MapLoader")
	loader.map_path = MAP_PATH
	loader.use_cmdline_map = false
	root.add_child(main)
	var runs: Node = main.get_node("RunManager")
	var guard: float = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 3.0:
		await _wait(0.1)
		guard += 0.1
	var sys: Node = main.get_node("EnemySystem")
	var player: CharacterBody3D = main.get_node("Player")
	var balls: Node = main.get_node("CannonBalls")
	_check(sys.count() == 2, "main scene: 2 enemies")
	_check(main.get_node("Destructibles").kinds().has(KIND_ENEMY), "enemies registered in Destructibles")
	# Freeze the hunter far away: park the player in the top-left corner (hunter window is 16 cells, it would come).
	player.global_position = loader.cell_to_world(Vector2i(1, 7))
	# Cannon ball at the crawler: aim from 3 cells west of it along its row, at its current cell.
	_destroyed.clear()
	var target: Vector2i = sys.cell_of(0)
	var from: Vector3 = loader.cell_to_world(target) + Vector3(-3.0, 0.55, 0.0)
	balls.launch(from, (loader.cell_to_world(sys.next_of(0)) + Vector3(0.0, 0.55, 0.0) - from).normalized(), 0.2)
	guard = 0.0
	while sys.is_alive(0) and guard < 1.0:
		await physics_frame
		guard += DT
	_check(not sys.is_alive(0), "a cannon ball destroys the crawler")
	var hit: Array = []
	for d in _destroyed:
		if d[0] == KIND_ENEMY:
			hit = d
	_check(not hit.is_empty() and hit[2] == CAUSE_CANNON, "destructible_destroyed(enemy, cannon): %s" % [_destroyed])
	_check(not sys.is_enemy_at(target), "the destroyed enemy holds no cell")
	# Touch the hunter: the run ends with enemy_hunter, the next run brings the crawler back.
	_ended.clear()
	var ended_cause: Array[StringName] = []
	root.get_node("SignalBus").connect("run_ended", func(c: StringName) -> void: ended_cause.append(c))
	player.global_position = sys.position_of(1)
	guard = 0.0
	while ended_cause.is_empty() and guard < 2.0:
		await physics_frame
		guard += DT
	_check(ended_cause == ([&"enemy_hunter"] as Array[StringName]), "touching the hunter ends the run: %s" % [ended_cause])
	guard = 0.0
	while runs.get("phase") != PHASE_PLAYING and guard < 3.0:
		await _wait(0.1)
		guard += 0.1
	_check(sys.alive_count() == 2 and sys.cell_of(0) == Vector2i(10, 2), "the new run brings every enemy back to its spawn")
	_check(main.get_node("EnemyView").call("drawn") >= 0, "enemy view runs")
	_done = true
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAP_PATH))
	Support.remove_file("user://test_progress_%s.tres" % SAVE_TAG)
