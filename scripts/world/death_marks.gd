class_name DeathMarks
extends Node
## Death marks (task-093), data layer and the only writer of the death stains and the invulnerability items.
##  - Every death (SignalBus.run_ended) sprays the drawn cells (floor and walls) within DeathMarksConfig.stain_radius of
##    the death cell: each gets stain strength (strongest at the centre, at most 1 per cell); SignalBus.death_stained.
##  - Every sprayed cell of every death counts towards `total_tiles`. When a death takes the count past another multiple
##    of tiles_per_item, it throws one invulnerability item (⚛) onto a free, harmless walkable cell near the death cell
##    (BFS within item_scatter_radius); SignalBus.invulnerability_item_dropped.
##  - The player standing on an item's cell during a run picks it up: Invulnerability.grant(invulnerable_seconds).
##  - Maps place items too (legend `I`, task-095): put back on every SignalBus.world_reset, picked up the same way.
## Stains and items are kept per map for the whole game launch (deaths, runs and map switches keep them; a restart of
## the game clears them). DeathMarksView draws them read-only.

const _DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
## Cell types the item may land on (walkable and harmless), and the ones the search may pass through.
const ITEM_TYPES: Array[StringName] = [MapLegend.FLOOR, MapLegend.SPAWN, MapLegend.ITEM]
const PASS_TYPES: Array[StringName] = [MapLegend.FLOOR, MapLegend.SPAWN, MapLegend.ITEM, MapLegend.SPIKES, MapLegend.CORRUPT]

@export var config: DeathMarksConfig
@export var map_loader: MapLoader
@export var player: Node3D
@export var invulnerability: Invulnerability
## Optional: pickups only while the run is PLAYING.
@export var run_manager: RunManager
## Optional: no item lands on a pushable object.
@export var pushables: PushableObjects

## Stained tiles of the launch (every sprayed cell of every death).
var total_tiles: int = 0
## Items picked up this launch (tests).
var taken: int = 0

## map id -> {cell: strength}
var _stains: Dictionary[StringName, Dictionary] = {}
## map id -> {cell: true}
var _items: Dictionary[StringName, Dictionary] = {}


func _ready() -> void:
	if config == null:
		config = DeathMarksConfig.new()
	SignalBus.run_ended.connect(func(_cause: StringName) -> void:
		if player != null:
			mark_death(player.global_position))
	if map_loader != null:
		map_loader.map_built.connect(func(_m: MapData) -> void: SignalBus.death_stains_reset.emit(_map_id()))
	SignalBus.world_reset.connect(place_map_items)


## Puts the map file's invulnerability items (legend `I`, task-095) back: the world reset (first run of a launch) shows
## the map's picture again. Thrown items stay; a map item picked up later stays gone across deaths (the world is kept).
func place_map_items() -> void:
	if map_loader == null:
		return
	var placed: Array[Vector2i] = []
	for cell: Vector2i in map_loader.data.invulnerability_items:
		if not items().has(cell):
			items()[cell] = true
			placed.append(cell)
	if not placed.is_empty():
		SignalBus.invulnerability_items_placed.emit(placed)


## Stain strength 0..1 of a cell of the current map.
func stain_at(cell: Vector2i) -> float:
	return float(stains().get(cell, 0.0))


## Stained cells of the current map: {cell: strength} (read-only).
func stains() -> Dictionary:
	if not _stains.has(_map_id()):
		_stains[_map_id()] = {}
	return _stains[_map_id()]


## Item cells of the current map: {cell: true} (read-only).
func items() -> Dictionary:
	if not _items.has(_map_id()):
		_items[_map_id()] = {}
	return _items[_map_id()]


func has_item(cell: Vector2i) -> bool:
	return items().has(cell)


## A death at `world_position`: sprays the stain, counts the tiles, maybe throws an item. Returns the sprayed cells.
func mark_death(world_position: Vector3) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if map_loader == null or map_loader.data.is_empty():
		return out
	var centre: Vector2i = map_loader.world_to_cell(world_position)
	var r: float = config.stain_radius
	var reach: int = ceili(r)
	var map_stains: Dictionary = stains()
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var d: float = Vector2(dx, dy).length()
			if d > r:
				continue
			var cell := Vector2i(centre.x + dx, centre.y + dy)
			if not map_loader.is_drawn(cell):
				continue
			var k: float = config.stain_strength * lerpf(1.0, config.stain_edge, d / maxf(r, 0.001))
			map_stains[cell] = minf(float(map_stains.get(cell, 0.0)) + k, 1.0)
			out.append(cell)
	if out.is_empty():
		return out
	var before: int = total_tiles
	total_tiles += out.size()
	SignalBus.death_stained.emit(_map_id(), out, total_tiles)
	var per: int = maxi(config.tiles_per_item, 1)
	if total_tiles / per > before / per:
		_drop_item(centre, world_position)
	return out


## Picks the item in `cell` up. False when there is none.
func take(cell: Vector2i) -> bool:
	var map_items: Dictionary = items()
	if not map_items.has(cell):
		return false
	map_items.erase(cell)
	taken += 1
	SignalBus.invulnerability_item_taken.emit(cell)
	if invulnerability != null:
		invulnerability.grant(config.invulnerable_seconds)
	return true


func _physics_process(_delta: float) -> void:
	if player == null or map_loader == null or items().is_empty():
		return
	if run_manager != null and run_manager.phase != RunManager.Phase.PLAYING:
		return
	take(map_loader.world_to_cell(player.global_position))


func _drop_item(centre: Vector2i, from_position: Vector3) -> void:
	var cell: Vector2i = _free_cell_near(centre)
	if cell == Vector2i(-1, -1):
		push_warning("[DeathMarks] No free cell for the invulnerability item near %s" % centre)
		return
	items()[cell] = true
	SignalBus.invulnerability_item_dropped.emit(cell, from_position)


## Nearest free harmless walkable cell by BFS steps from `from` (through hazards too); (-1, -1) when none.
func _free_cell_near(from: Vector2i) -> Vector2i:
	var seen: Dictionary[Vector2i, bool] = {from: true}
	var ring: Array[Vector2i] = [from]
	for step in config.item_scatter_radius + 1:
		for c in ring:
			if _is_free(c):
				return c
		var next_ring: Array[Vector2i] = []
		for c in ring:
			for d in _DIRS:
				var n: Vector2i = c + d
				if seen.has(n) or not PASS_TYPES.has(map_loader.data.type_at(n)):
					continue
				seen[n] = true
				next_ring.append(n)
		ring = next_ring
	return Vector2i(-1, -1)


func _is_free(c: Vector2i) -> bool:
	if not map_loader.data.in_bounds(c) or not ITEM_TYPES.has(map_loader.data.type_at(c)):
		return false
	if items().has(c):
		return false
	return pushables == null or pushables.object_at(c) < 0


func _map_id() -> StringName:
	return map_loader.map_id if map_loader != null else &""
