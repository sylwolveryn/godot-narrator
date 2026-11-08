class_name EnemyRemains
extends Node
## Enemy remains (task-076), data layer and the only writer of the diamonds and the black holes of the run.
##  - SignalBus.enemy_destroyed (any cause: a cannon ball, a black hole): an enemy whose EnemyDef.diamonds > 0 (crawler,
##    wanderer) bursts into that many diamonds on free cells near its cell (BFS over enemy-walkable cells within
##    RemainsConfig.scatter_radius, no diamond or black hole there; nearest first, ties shuffled); SignalBus.diamonds_spawned.
##    An enemy with EnemyDef.black_hole (hunter) leaves a black hole on its cell; SignalBus.black_hole_formed and the
##    narration event BLACK_HOLE_FORMED.
##  - Diamonds: the player standing on a diamond's cell picks it up (any time in a run): PersistentProgress.diamonds += 1
##    (saved at once), SignalBus.diamond_collected, the narration event DIAMOND_FOUND. No other effect yet.
##  - Black holes: placed in the map file (legend MapLegend.black_hole_char, `O`) or formed by hunters. Harmless and
##    walkable for the player (no pull, no damage); EnemySystem destroys any enemy arriving on one (cause black_hole),
##    which leaves its normal remains (diamonds, or another black hole for a hunter).
## Both persist for the run only: at every run start (and map build) the diamonds are gone and the black holes are the
## map file's again (SignalBus.remains_reset). RemainsView draws them read-only.

@export var config: RemainsConfig
@export var enemies: EnemySystem
@export var map_loader: MapLoader
## Optional: the player picks diamonds up.
@export var player: Node3D
## Optional: the diamond counter lives in the save.
@export var save_service: SaveService
## Optional: pickups only while the run is PLAYING.
@export var run_manager: RunManager

## Seedable (tests): scatter tie order.
var rng := RandomNumberGenerator.new()

var _diamonds: Dictionary[Vector2i, bool] = {}
var _holes: Dictionary[Vector2i, bool] = {}
## Black hole cells in formation order (map holes first).
var _hole_list: Array[Vector2i] = []
## Diamonds picked up this launch (tests; the save holds the total).
var collected: int = 0


func _ready() -> void:
	if config == null:
		config = RemainsConfig.new()
	rng.randomize()
	SignalBus.enemy_destroyed.connect(_on_enemy_destroyed)
	SignalBus.run_started.connect(func(_i: int) -> void: reset())
	if map_loader != null:
		map_loader.map_built.connect(func(_m: MapData) -> void: reset())
		if not map_loader.data.is_empty():
			reset()


func is_black_hole(cell: Vector2i) -> bool:
	return _holes.has(cell)


func has_diamond(cell: Vector2i) -> bool:
	return _diamonds.has(cell)


func diamond_count() -> int:
	return _diamonds.size()


## Diamond cells (read-only).
func diamonds() -> Dictionary[Vector2i, bool]:
	return _diamonds


## Black hole cells in formation order (read-only).
func holes() -> Array[Vector2i]:
	return _hole_list


## Diamonds collected ever (the save), or this launch without a save.
func total_collected() -> int:
	return save_service.progress.diamonds if save_service != null else collected


## Diamonds gone, black holes back to the map file's (run start, map build).
func reset() -> void:
	_diamonds.clear()
	_holes.clear()
	_hole_list.clear()
	if map_loader != null:
		for cell in map_loader.data.black_holes:
			if not _holes.has(cell):
				_holes[cell] = true
				_hole_list.append(cell)
	SignalBus.remains_reset.emit()


## Adds a black hole in `cell` (false when one is there already).
func form_black_hole(cell: Vector2i) -> bool:
	if _holes.has(cell):
		return false
	_holes[cell] = true
	_hole_list.append(cell)
	SignalBus.black_hole_formed.emit(cell, map_loader.cell_to_world(cell))
	SignalBus.narration_event.emit(NarrationEvents.BLACK_HOLE_FORMED)
	return true


## Scatters `n` diamonds around `cell`; returns the cells they landed on.
func spawn_diamonds(cell: Vector2i, n: int, from_position: Vector3) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var room: int = mini(n, config.max_diamonds - _diamonds.size())
	if room <= 0:
		return out
	for c in _free_cells_near(cell):
		if out.size() >= room:
			break
		_diamonds[c] = true
		out.append(c)
	if not out.is_empty():
		SignalBus.diamonds_spawned.emit(from_position, out)
	return out


## Picks the diamond in `cell` up. False when there is none.
func collect(cell: Vector2i) -> bool:
	if not _diamonds.has(cell):
		return false
	_diamonds.erase(cell)
	collected += 1
	if save_service != null:
		save_service.progress.diamonds += 1
		save_service.commit_progress()
	SignalBus.consumed.emit(Consumable.DIAMOND)
	SignalBus.diamond_collected.emit(cell, total_collected())
	SignalBus.narration_event.emit(NarrationEvents.DIAMOND_FOUND)
	return true


func _physics_process(_delta: float) -> void:
	if _diamonds.is_empty() or player == null or map_loader == null:
		return
	if run_manager != null and run_manager.phase != RunManager.Phase.PLAYING:
		return
	collect(map_loader.world_to_cell(player.global_position))


func _on_enemy_destroyed(kind: StringName, cell: Vector2i, world_position: Vector3, _cause: StringName) -> void:
	var def: EnemyDef = enemies.resolved.def_for(kind) if enemies != null and enemies.resolved != null else null
	if def == null:
		return
	if def.black_hole:
		form_black_hole(cell)
	if def.diamonds > 0:
		spawn_diamonds(cell, def.diamonds, world_position)


## Free cells around `cell` by BFS steps (nearest first; cells at one distance shuffled).
func _free_cells_near(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen: Dictionary[Vector2i, bool] = {cell: true}
	var ring: Array[Vector2i] = [cell]
	for step in config.scatter_radius + 1:
		var free_ring: Array[Vector2i] = []
		for c in ring:
			if _is_free(c):
				free_ring.append(c)
		_shuffle(free_ring)
		out.append_array(free_ring)
		var next_ring: Array[Vector2i] = []
		for c in ring:
			for d in EnemySystem.DIRS:
				var n: Vector2i = c + d
				if seen.has(n) or not _walkable(n):
					continue
				seen[n] = true
				next_ring.append(n)
		ring = next_ring
	return out


func _is_free(c: Vector2i) -> bool:
	return _walkable(c) and not _diamonds.has(c) and not _holes.has(c)


func _walkable(c: Vector2i) -> bool:
	return enemies.is_walkable(c) if enemies != null else map_loader.data.type_at(c) == MapLegend.FLOOR


func _shuffle(cells: Array[Vector2i]) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
