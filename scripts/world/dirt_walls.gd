class_name DirtWalls
extends Node3D
## Data layer of the dirt walls `D` (task-070): the only writer of the dirt state. A dirt cell blocks movement, sight and
## light like a wall (its type is MapLegend.DIRT in MapData; light_blocking_types holds it) until it is destroyed; then
## it is floor. The ONE entry point is `destroy(cell, cause)`, reached through SignalBus.dirt_destroy_requested (the
## player eats a cell it pushes into; later a cannon ball). Destroyed cells become dirt again at every run start.
##
## Scales to large maps (a 200x200 map of ~39,000 D cells): collision lives in square chunks (DirtConfig.chunk_size), one
## StaticBody3D per chunk with one box per horizontal run of dirt in it; destroying a cell rebuilds only the boxes of its
## chunk (<= chunk_size rows). No per-frame work at all.
##
## Eating (cause CAUSE_EATEN) counts in the save (PersistentProgress.walls_eaten), fires WALL_EATEN every time and
## WALLS_DEVOURED when the counter reaches the next milestone (a random gap in [milestone_min, milestone_max], re-rolled
## after each milestone, stored as next_devour_at).

const CAUSE_EATEN: StringName = &"eaten"

@export var config: DirtConfig
@export var map_loader: MapLoader
@export var save_service: SaveService

## Seedable (tests): the milestone gaps.
var rng := RandomNumberGenerator.new()

## Dirt cells of the map file (restored at run start).
var _home: Dictionary[Vector2i, bool] = {}
## Destroyed home cells (floor now).
var _destroyed: Dictionary[Vector2i, bool] = {}
## Chunk -> its collision body (only chunks that hold dirt in the map file).
var _bodies: Dictionary[Vector2i, StaticBody3D] = {}


func _ready() -> void:
	if config == null:
		config = DirtConfig.new()
	rng.randomize()
	SignalBus.dirt_destroy_requested.connect(destroy)
	SignalBus.run_started.connect(func(_i: int) -> void: restore())
	if map_loader != null:
		map_loader.map_built.connect(_on_map_built)
		if not map_loader.data.is_empty():
			_on_map_built(map_loader.data)


## True when the cell is dirt right now.
func is_dirt(cell: Vector2i) -> bool:
	return map_loader != null and map_loader.data.type_at(cell) == MapLegend.DIRT


## Dirt cells left on the map.
func count_left() -> int:
	return _home.size() - _destroyed.size()


## Dirt cells of the map file.
func home_count() -> int:
	return _home.size()


## Chunk holding a cell.
func chunk_of(cell: Vector2i) -> Vector2i:
	var n: int = maxi(config.chunk_size, 1)
	return Vector2i(floori(float(cell.x) / n), floori(float(cell.y) / n))


## Cells of a chunk (clipped to the map).
func chunk_rect(chunk: Vector2i) -> Rect2i:
	var n: int = maxi(config.chunk_size, 1)
	var r := Rect2i(chunk * n, Vector2i(n, n))
	return r.intersection(Rect2i(0, 0, map_loader.data.width, map_loader.data.height))


## Collision boxes of a chunk (tests).
func chunk_box_count(chunk: Vector2i) -> int:
	var body: StaticBody3D = _bodies.get(chunk, null)
	return body.get_child_count() if body != null else 0


## Destroys a dirt cell: it becomes floor (collision, sight and light follow the map data at once) and
## SignalBus.dirt_destroyed is emitted. False when the cell is not dirt.
func destroy(cell: Vector2i, cause: StringName = CAUSE_EATEN) -> bool:
	if not is_dirt(cell):
		return false
	map_loader.data.set_type(cell, MapLegend.FLOOR)
	_destroyed[cell] = true
	_rebuild_chunk(chunk_of(cell))
	SignalBus.dirt_destroyed.emit(map_loader.map_id, cell, cause)
	if cause == CAUSE_EATEN:
		_count_eaten()
	return true


## Every destroyed cell becomes dirt again (run start); only the chunks that changed are rebuilt.
func restore() -> void:
	if _destroyed.is_empty() or map_loader == null:
		return
	var cells: Array[Vector2i] = []
	var chunks: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in _destroyed:
		map_loader.data.set_type(cell, MapLegend.DIRT)
		cells.append(cell)
		chunks[chunk_of(cell)] = true
	_destroyed.clear()
	for chunk: Vector2i in chunks:
		_rebuild_chunk(chunk)
	SignalBus.dirt_restored.emit(cells)


func _count_eaten() -> void:
	if save_service == null:
		SignalBus.narration_event.emit(NarrationEvents.WALL_EATEN)
		return
	var p: PersistentProgress = save_service.progress
	if p.next_devour_at <= p.walls_eaten:
		p.next_devour_at = p.walls_eaten + _gap()
	p.walls_eaten += 1
	SignalBus.narration_event.emit(NarrationEvents.WALL_EATEN)
	if p.walls_eaten >= p.next_devour_at:
		p.next_devour_at = p.walls_eaten + _gap()
		save_service.commit_progress()
		SignalBus.narration_event.emit(NarrationEvents.WALLS_DEVOURED)
	else:
		save_service.mark_dirty()


func _gap() -> int:
	var lo: int = maxi(config.milestone_min, 1)
	return rng.randi_range(lo, maxi(config.milestone_max, lo))


func _on_map_built(map: MapData) -> void:
	for body: StaticBody3D in _bodies.values():
		body.free()
	_bodies.clear()
	_home.clear()
	_destroyed.clear()
	var chunks: Dictionary[Vector2i, bool] = {}
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			if map.type_at(cell) == MapLegend.DIRT:
				_home[cell] = true
				chunks[chunk_of(cell)] = true
	for chunk: Vector2i in chunks:
		var body := StaticBody3D.new()
		body.name = "DirtChunk_%d_%d" % [chunk.x, chunk.y]
		body.set_meta(&"cell_type", MapLegend.DIRT)
		add_child(body)
		_bodies[chunk] = body
		_rebuild_chunk(chunk)


## Replaces a chunk's boxes: one per horizontal run of dirt cells in each of its rows.
func _rebuild_chunk(chunk: Vector2i) -> void:
	var body: StaticBody3D = _bodies.get(chunk, null)
	if body == null:
		return
	for child in body.get_children():
		body.remove_child(child)
		child.free()
	var map: MapData = map_loader.data
	var s: float = map_loader.world_config.cell_size
	var h: float = map_loader.world_config.wall_height
	var r: Rect2i = chunk_rect(chunk)
	for y in range(r.position.y, r.end.y):
		var x: int = r.position.x
		while x < r.end.x:
			if map.type_at(Vector2i(x, y)) != MapLegend.DIRT:
				x += 1
				continue
			var run: int = 0
			while x + run < r.end.x and map.type_at(Vector2i(x + run, y)) == MapLegend.DIRT:
				run += 1
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(run * s, h, s)
			shape.shape = box
			shape.position = Vector3((x + run * 0.5) * s, h * 0.5, (y + 0.5) * s)
			body.add_child(shape)
			x += run
