class_name EnemySystem
extends Node
## Enemies (task-075), data layer and the only writer of the enemy state. On every map build and run start every enemy
## of the map file (MapData.enemies, legend L R H W) stands on its spawn cell again, alive (destroyed ones come back,
## like dirt). Enemies move cell to cell on the 4 grid directions, interpolated at their kind's speed:
##  - crawler (L / R): wall following with the left-hand (L) or right-hand (R) rule. While a wall is beside it (the side
##    cell or the cell behind that side is blocked) it turns towards the wall side round corners, else goes straight,
##    else turns away, else back: it never loses its wall. With no wall beside it (open floor, or its wall was
##    destroyed) it goes straight until it meets one and then turns away from it, keeping it on its side.
##  - hunter (H): breadth-first search on the cell grid towards the player inside a window of search_radius cells,
##    redone every repath_seconds (or when its next step is blocked); walls, dirt, props, cannons and pushable
##    objects block it, it never digs. A player outside the window (or unreachable) is not hunted: it wanders.
##  - wanderer (W): keeps a random free direction for a random run of run_min..run_max cells, re-rolls at junctions
##    (turn_chance), when blocked and when the run ends; it turns back only in a dead end.
## Blocked for every enemy: walls, void, dirt, large props (gargoyles, cannons), pushable objects; other enemies hold the
## cell they stand on and the one they move into (no stacking; an enemy waits for a held cell, and after
## block_wait_seconds tries another way). Hazards (spikes, corruption) are harmless to enemies; black holes are not
## blocked: an enemy arriving on one (EnemyRemains.is_black_hole) is destroyed with cause CAUSE_BLACK_HOLE.
## Touching the player (contact_radius + body radius) while the run is PLAYING ends the run once:
## SignalBus.hazard_lethal + SignalBus.run_end_requested(&"enemy_<kind>").
## Destructibles kind KIND: a cannon ball entering a cell an enemy holds destroys it. Every destruction emits
## SignalBus.destructible_destroyed(KIND, ...) and SignalBus.enemy_destroyed(kind, cell, ...) (remains hook in there).
## Per-kind numbers: EnemyConfig, overridden by the DB table enemy_def. EnemyView draws the state read-only.

const KIND: StringName = &"enemy"
const CAUSE_BLACK_HOLE: StringName = &"black_hole"
## Grid directions, clockwise: north (-y), east, south, west.
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const NO_DIR: int = -1
## Cell types an enemy may stand on.
const WALKABLE: Array[StringName] = [MapLegend.FLOOR, MapLegend.SPAWN, MapLegend.SPIKES, MapLegend.CORRUPT, MapLegend.ITEM]

@export var config: EnemyConfig
@export var map_loader: MapLoader
## Optional: the player body (contact, hunting).
@export var player: Node3D
@export var player_config: PlayerConfig
## Optional: enemies move only while the run is PLAYING (always without it).
@export var run_manager: RunManager
@export var destructibles: Destructibles
## Optional: pushable objects block enemies.
@export var pushables: PushableObjects
## Optional: black holes destroy enemies (task-076).
@export var remains: EnemyRemains
## Optional: per-kind numbers from the DB table enemy_def.
@export var database: GameDatabase

## Seedable (tests): wanderer rolls, crawler waits.
var rng := RandomNumberGenerator.new()
## Config with the DB rows applied.
var resolved: EnemyConfig

var _def: Array[EnemyDef] = []
var _spawn_cell: Array[Vector2i] = []
var _spawn_type: Array[StringName] = []
var _hand := PackedInt32Array()
var _alive: Array[bool] = []
var _cell: Array[Vector2i] = []
var _next: Array[Vector2i] = []
var _t := PackedFloat32Array()
var _dir := PackedInt32Array()
var _run_left := PackedInt32Array()
var _wait := PackedFloat32Array()
var _repath := PackedFloat32Array()
var _paths: Array[Array] = []
var _pos := PackedVector3Array()
## Cell -> index of the enemy holding it (standing on it or moving into it).
var _held: Dictionary[Vector2i, int] = {}
var _fired: bool = false
## Path searches done in the current physics step.
var _step_searches: int = 0
## BFS scratch (reused).
var _parent := PackedInt32Array()
var _queue := PackedInt32Array()

## Counters (tests, perf): cells entered, path searches, physics steps measured and their summed time.
var steps: int = 0
var searches: int = 0
var step_count: int = 0
var step_usec: int = 0


func _ready() -> void:
	if config == null:
		config = EnemyConfig.new()
	rng.randomize()
	resolved = config.from_tables(database.tables) if database != null else config
	if database != null:
		database.tables_loaded.connect(_on_tables_loaded)
	if destructibles != null:
		destructibles.register(KIND, is_enemy_at, destroy)
	SignalBus.run_started.connect(func(_i: int) -> void: reset())
	if map_loader != null:
		map_loader.map_built.connect(func(_m: MapData) -> void: reset())
		if not map_loader.data.is_empty():
			reset()


# --------------------------------------------------------------------------- queries (views, tests)

func count() -> int:
	return _def.size()


func alive_count() -> int:
	var n: int = 0
	for a in _alive:
		n += 1 if a else 0
	return n


func is_alive(i: int) -> bool:
	return _alive[i]


func def_of(i: int) -> EnemyDef:
	return _def[i]


func kind_of(i: int) -> StringName:
	return _def[i].kind


func hand_of(i: int) -> int:
	return _hand[i]


## The cell the enemy stands on (the one it left while moving).
func cell_of(i: int) -> Vector2i:
	return _cell[i]


## The cell it moves into (its cell when standing).
func next_of(i: int) -> Vector2i:
	return _next[i]


## World position (floor level).
func position_of(i: int) -> Vector3:
	return _pos[i]


## Facing (DIRS index) of the last move.
func dir_of(i: int) -> int:
	return _dir[i]


## Destructibles hook: an alive enemy holds `cell`.
func is_enemy_at(cell: Vector2i) -> bool:
	return _held.has(cell)


## Index of the enemy holding `cell`, -1 when none.
func enemy_at(cell: Vector2i) -> int:
	return _held.get(cell, -1)


## Static walkability for enemies (other enemies not counted).
func is_walkable(cell: Vector2i) -> bool:
	if map_loader == null or not map_loader.data.in_bounds(cell):
		return false
	if not WALKABLE.has(map_loader.data.type_at(cell)):
		return false
	return pushables == null or pushables.object_at(cell) < 0


## Average cost of one physics step of the system, microseconds (perf).
func average_step_usec() -> float:
	return float(step_usec) / float(maxi(step_count, 1))


# --------------------------------------------------------------------------- lifecycle

## Every enemy of the map stands on its spawn cell again, alive (run start, map build).
func reset() -> void:
	_def.clear()
	_spawn_cell.clear()
	_spawn_type.clear()
	_alive.clear()
	_cell.clear()
	_next.clear()
	_paths.clear()
	_held.clear()
	_fired = false
	var map: MapData = map_loader.data if map_loader != null else null
	if map != null:
		for k in map.enemies.size():
			var def: EnemyDef = resolved.def_for_spawn(map.enemy_types[k])
			if def == null:
				push_warning("[EnemySystem] No enemy def for spawn type %s" % map.enemy_types[k])
				continue
			_def.append(def)
			_spawn_cell.append(map.enemies[k])
			_spawn_type.append(map.enemy_types[k])
	var n: int = _def.size()
	_hand.resize(n)
	_t.resize(n)
	_t.fill(0.0)
	_dir.resize(n)
	_run_left.resize(n)
	_run_left.fill(0)
	_wait.resize(n)
	_wait.fill(0.0)
	_repath.resize(n)
	_pos.resize(n)
	for i in n:
		var cell: Vector2i = _spawn_cell[i]
		_hand[i] = resolved.hand_for_spawn(_spawn_type[i])
		_alive.append(true)
		_cell.append(cell)
		_next.append(cell)
		_paths.append([])
		_dir[i] = _start_dir(cell, i)
		_repath[i] = rng.randf() * _def[i].repath_seconds
		_held[cell] = i
		_pos[i] = map_loader.cell_to_world(cell)
	SignalBus.enemies_reset.emit(n)


## Destroys the enemy holding `cell` (Destructibles contract). False when none is there.
func destroy(cell: Vector2i, cause: StringName) -> bool:
	var i: int = enemy_at(cell)
	if i < 0 or not _alive[i]:
		return false
	_kill(i, cause)
	return true


func _kill(i: int, cause: StringName) -> void:
	_alive[i] = false
	if _held.get(_cell[i], -1) == i:
		_held.erase(_cell[i])
	if _held.get(_next[i], -1) == i:
		_held.erase(_next[i])
	var at: Vector2i = map_loader.world_to_cell(_pos[i])
	var world: Vector3 = _pos[i]
	SignalBus.destructible_destroyed.emit(KIND, Rect2i(at, Vector2i.ONE), world, cause)
	SignalBus.enemy_destroyed.emit(_def[i].kind, at, world, cause)


# --------------------------------------------------------------------------- stepping

func _physics_process(delta: float) -> void:
	if _def.is_empty() or map_loader == null:
		return
	if run_manager != null and run_manager.phase != RunManager.Phase.PLAYING:
		return
	var t0: int = Time.get_ticks_usec()
	_step_searches = 0
	var player_cell := Vector2i(-1000000, -1000000)
	if player != null:
		player_cell = map_loader.world_to_cell(player.global_position)
	for i in _def.size():
		if _alive[i]:
			_step(i, delta, player_cell)
	if player != null and not _fired:
		_check_contact()
	step_usec += Time.get_ticks_usec() - t0
	step_count += 1


func _step(i: int, delta: float, player_cell: Vector2i) -> void:
	var def: EnemyDef = _def[i]
	_repath[i] -= delta
	if _next[i] != _cell[i]:
		_t[i] += def.speed * delta
		if _t[i] < 1.0:
			_pos[i] = map_loader.cell_to_world(_cell[i]).lerp(map_loader.cell_to_world(_next[i]), _t[i])
			return
		var leftover: float = _t[i] - 1.0
		_arrive(i)
		if not _alive[i]:
			return
		_decide(i, delta, player_cell)
		if _next[i] != _cell[i]:
			_t[i] = minf(leftover, 0.99)
	else:
		_decide(i, delta, player_cell)
	_pos[i] = map_loader.cell_to_world(_cell[i]).lerp(map_loader.cell_to_world(_next[i]), _t[i])


func _arrive(i: int) -> void:
	if _held.get(_cell[i], -1) == i:
		_held.erase(_cell[i])
	_cell[i] = _next[i]
	_t[i] = 0.0
	_pos[i] = map_loader.cell_to_world(_cell[i])
	steps += 1
	if remains != null and remains.is_black_hole(_cell[i]):
		_kill(i, CAUSE_BLACK_HOLE)


## Picks the next cell and holds it (or waits for a cell another enemy holds).
func _decide(i: int, delta: float, player_cell: Vector2i) -> void:
	var d: int = _choose(i, player_cell)
	if d == NO_DIR:
		return
	var target: Vector2i = _cell[i] + DIRS[d]
	var holder: int = _held.get(target, -1)
	if holder >= 0 and holder != i:
		_wait[i] += delta
		if _wait[i] >= resolved.block_wait_seconds:
			_wait[i] = 0.0
			_dir[i] = (d + 2) % 4
			_run_left[i] = 0
			_paths[i].clear()
		return
	_wait[i] = 0.0
	_dir[i] = d
	_next[i] = target
	_t[i] = 0.0
	_held[target] = i


func _choose(i: int, player_cell: Vector2i) -> int:
	match _def[i].movement:
		EnemyDef.Movement.CRAWLER:
			return _crawl(i)
		EnemyDef.Movement.HUNTER:
			var d: int = _hunt(i, player_cell)
			return d if d != NO_DIR else _wander(i)
		_:
			return _wander(i)


func _free(cell: Vector2i, d: int) -> bool:
	return is_walkable(cell + DIRS[d])


## Wall following (left-hand rule for hand HAND_LEFT, right-hand for HAND_RIGHT).
func _crawl(i: int) -> int:
	var cell: Vector2i = _cell[i]
	var d: int = _dir[i]
	var side: int = (d + (3 if _hand[i] == EnemyConfig.HAND_LEFT else 1)) % 4
	var away: int = (side + 2) % 4
	var back: int = (d + 2) % 4
	var wall_beside: bool = not _free(cell, side) or not is_walkable(cell + DIRS[side] + DIRS[back])
	if wall_beside:
		if _free(cell, side):
			return side
		if _free(cell, d):
			return d
		if _free(cell, away):
			return away
		return back if _free(cell, back) else NO_DIR
	if _free(cell, d):
		return d
	if _free(cell, away):
		return away
	if _free(cell, side):
		return side
	return back if _free(cell, back) else NO_DIR


## Random runs: keep the direction for run_left cells, re-roll at junctions (turn_chance), when blocked or done.
func _wander(i: int) -> int:
	var def: EnemyDef = _def[i]
	var cell: Vector2i = _cell[i]
	var d: int = _dir[i]
	var free_dirs: Array[int] = []
	for k in 4:
		if _free(cell, k):
			free_dirs.append(k)
	if free_dirs.is_empty():
		return NO_DIR
	var keep: bool = d != NO_DIR and free_dirs.has(d) and _run_left[i] > 0
	if keep and free_dirs.size() >= 3 and rng.randf() < def.turn_chance:
		keep = false
	if keep:
		_run_left[i] -= 1
		return d
	var choices: Array[int] = []
	for k in free_dirs:
		if d == NO_DIR or k != (d + 2) % 4:
			choices.append(k)
	if choices.is_empty():
		choices = free_dirs
	var pick: int = choices[rng.randi_range(0, choices.size() - 1)]
	_run_left[i] = maxi(rng.randi_range(def.run_min, maxi(def.run_max, def.run_min)) - 1, 0)
	return pick


## Next direction towards the player along a BFS path, NO_DIR when the player is out of reach.
func _hunt(i: int, player_cell: Vector2i) -> int:
	var def: EnemyDef = _def[i]
	var cell: Vector2i = _cell[i]
	var r: int = def.search_radius
	if absi(player_cell.x - cell.x) > r or absi(player_cell.y - cell.y) > r:
		_paths[i].clear()
		return NO_DIR
	var path: Array = _paths[i]
	var stale: bool = path.is_empty() or _repath[i] <= 0.0
	if not stale:
		var nxt: Vector2i = path[0]
		stale = absi(nxt.x - cell.x) + absi(nxt.y - cell.y) != 1 or not is_walkable(nxt)
	if stale and _step_searches >= resolved.max_searches_per_step:
		stale = path.is_empty() or not is_walkable(path[0]) or absi((path[0] as Vector2i).x - cell.x) + absi((path[0] as Vector2i).y - cell.y) != 1
		if stale:
			return NO_DIR
	if stale:
		_step_searches += 1
		_repath[i] = def.repath_seconds
		path = _search(cell, player_cell, r)
		_paths[i] = path
	if path.is_empty():
		return NO_DIR
	var step: Vector2i = path.pop_front()
	return DIRS.find(step - cell)


## BFS from `from` to `to` inside the window of radius `r`; the cells after `from` up to `to`, empty when unreachable.
func _search(from: Vector2i, to: Vector2i, r: int) -> Array:
	searches += 1
	if from == to:
		return []
	var w: int = r * 2 + 1
	var origin: Vector2i = from - Vector2i(r, r)
	var n: int = w * w
	if _parent.size() != n:
		_parent.resize(n)
		_queue.resize(n)
	_parent.fill(-1)
	var start: int = r * w + r
	var goal: int = (to.y - origin.y) * w + (to.x - origin.x)
	_parent[start] = start
	_queue[0] = start
	var head: int = 0
	var tail: int = 1
	var found: bool = false
	while head < tail:
		var cur: int = _queue[head]
		head += 1
		if cur == goal:
			found = true
			break
		var cx: int = cur % w
		@warning_ignore("integer_division")
		var cy: int = cur / w
		for d in 4:
			var nx: int = cx + DIRS[d].x
			var ny: int = cy + DIRS[d].y
			if nx < 0 or ny < 0 or nx >= w or ny >= w:
				continue
			var ni: int = ny * w + nx
			if _parent[ni] >= 0:
				continue
			var cell := Vector2i(origin.x + nx, origin.y + ny)
			if ni != goal and not is_walkable(cell):
				continue
			_parent[ni] = cur
			_queue[tail] = ni
			tail += 1
	if not found:
		return []
	var out: Array = []
	var k: int = goal
	while k != start:
		@warning_ignore("integer_division")
		out.push_front(Vector2i(origin.x + k % w, origin.y + k / w))
		k = _parent[k]
	return out


func _check_contact() -> void:
	if run_manager != null and run_manager.phase != RunManager.Phase.PLAYING:
		return
	var p: Vector3 = player.global_position
	var reach: float = resolved.contact_radius + (player_config.body_radius if player_config != null else 0.0)
	var reach_sq: float = reach * reach
	for i in _def.size():
		if not _alive[i] or not _def[i].lethal:
			continue
		var dx: float = _pos[i].x - p.x
		var dz: float = _pos[i].z - p.z
		if dx * dx + dz * dz < reach_sq:
			_fired = true
			SignalBus.hazard_lethal.emit(_def[i].end_cause(), _def[i].color)
			SignalBus.run_end_requested.emit(_def[i].end_cause())
			return


## Start facing: crawlers face along their wall (the wall on their side), the others a random free direction.
func _start_dir(cell: Vector2i, i: int) -> int:
	if _def[i].movement == EnemyDef.Movement.CRAWLER:
		var left: bool = _hand[i] == EnemyConfig.HAND_LEFT
		for d in 4:
			var side: int = (d + (3 if left else 1)) % 4
			if _free(cell, d) and not _free(cell, side):
				return d
	for d in 4:
		if _free(cell, d):
			return d
	return 0


func _on_tables_loaded(tables: Dictionary) -> void:
	resolved = config.from_tables(tables)
	for i in _def.size():
		var def: EnemyDef = resolved.def_for(_def[i].kind)
		if def != null:
			_def[i] = def
