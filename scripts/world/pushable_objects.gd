class_name PushableObjects
extends Node3D
## Data layer of the small pushable objects (task-019). Reads the object start cells from the loaded map, keeps their
## current cells and one StaticBody3D each (so every form is blocked by them), and lets the grown entity push them:
## Sokoban style, one cell at a time along a world axis. When the entity presses against an object (the movement input
## points at it, it touches the collision box) for `push_hold_time`, the object slides one cell if the target cell is
## allowed (PushConfig.allowed_target_types), holds no other object and is not the entity's cell. The single glyph never
## pushes. Objects return to their map cells at every run start (no persistence).
## Speaks through SignalBus.object_moved and its own `objects_reset`; the presentation (ObjectGlyphView) only listens.

## Emitted after the objects were (re)placed at their map cells: on a map build and on every run start.
signal objects_reset

@export var config: PushConfig
@export var map_loader: MapLoader
@export var player: Player
## Source of the active form (only the forms of PushConfig.pushing_forms push).
@export var entity: EntityProgression
## Optional. Pushing only happens while the run is PLAYING.
@export var run_manager: RunManager

var _home: Array[Vector2i] = []
var _cells: Array[Vector2i] = []
var _bodies: Array[StaticBody3D] = []
## Seconds left of each object's slide; a sliding object cannot be pushed again.
var _busy: PackedFloat32Array = PackedFloat32Array()
var _cooldown: float = 0.0
var _hold: float = 0.0
var _hold_key: Vector3i = Vector3i(-1, 0, 0)


func _ready() -> void:
	if config == null:
		config = PushConfig.new()
	SignalBus.run_started.connect(_on_run_started)
	if map_loader != null:
		map_loader.map_built.connect(_on_map_built)
		if not map_loader.data.is_empty():
			_on_map_built(map_loader.data)


func _physics_process(delta: float) -> void:
	for i in _busy.size():
		_busy[i] = maxf(0.0, _busy[i] - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cells.is_empty() or player == null or map_loader == null:
		return
	if run_manager != null and run_manager.phase != RunManager.Phase.PLAYING:
		_hold = 0.0
		return
	var target: Vector3i = _pressed_object()
	if target.x < 0 or not can_form_push():
		_hold = 0.0
		_hold_key = Vector3i(-1, 0, 0)
		return
	if target != _hold_key:
		_hold_key = target
		_hold = 0.0
	_hold += delta
	if _hold >= config.push_hold_time and _cooldown <= 0.0:
		if try_push(target.x, Vector2i(target.y, target.z)):
			_cooldown = config.push_cooldown
		_hold = 0.0


## Number of objects of the built map.
func count() -> int:
	return _cells.size()


## Current cell of an object.
func cell_of(id: int) -> Vector2i:
	return _cells[id]


## Map cell an object starts every run on.
func home_of(id: int) -> Vector2i:
	return _home[id]


## Id of the object standing on a cell, -1 when there is none.
func object_at(cell: Vector2i) -> int:
	return _cells.find(cell)


## True while the object slides (it cannot be pushed then).
func is_sliding(id: int) -> bool:
	return _busy[id] > 0.0


## True when the active form can push objects.
func can_form_push() -> bool:
	return entity != null and config.pushing_forms.has(entity.current_form())


## True when an object may slide onto the cell: allowed cell type, no other object, not the entity's own cell.
func is_target_free(cell: Vector2i) -> bool:
	if map_loader == null or not map_loader.data.in_bounds(cell):
		return false
	if not config.allowed_target_types.has(map_loader.data.type_at(cell)):
		return false
	if object_at(cell) >= 0:
		return false
	return player == null or map_loader.world_to_cell(player.global_position) != cell


## Pushes an object one cell along `dir` (a unit step on one axis). False when the form cannot push, the object is
## sliding or the target cell is blocked. On success the object counts as standing on the target cell at once (its
## collision moves with it), SignalBus.object_moved is emitted and the presentation slides it.
func try_push(id: int, dir: Vector2i) -> bool:
	if id < 0 or id >= _cells.size() or absi(dir.x) + absi(dir.y) != 1:
		return false
	if not can_form_push() or is_sliding(id):
		return false
	var from: Vector2i = _cells[id]
	var to: Vector2i = from + dir
	if not is_target_free(to):
		return false
	_cells[id] = to
	_bodies[id].position = _body_position(to)
	_busy[id] = config.slide_duration
	SignalBus.object_moved.emit(id, from, to, entity.current_form())
	return true


## Puts every object back on its map cell.
func reset() -> void:
	for i in _cells.size():
		_cells[i] = _home[i]
		_bodies[i].position = _body_position(_home[i])
		_busy[i] = 0.0
	_cooldown = 0.0
	_hold = 0.0
	objects_reset.emit()


func _on_map_built(map: MapData) -> void:
	for body in _bodies:
		remove_child(body)
		body.free()
	_bodies.clear()
	_home = map.objects.duplicate()
	_cells = map.objects.duplicate()
	_busy.resize(_home.size())
	_busy.fill(0.0)
	var size: float = map_loader.world_config.cell_size
	var edge: float = size * map_loader.world_config.object_collision_ratio
	var height: float = map_loader.world_config.wall_height
	for i in _home.size():
		var body := StaticBody3D.new()
		body.name = "Object_%d" % i
		body.set_meta(&"cell_type", MapLegend.OBJECT)
		body.add_to_group(&"map_objects")
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(edge, height, edge)
		shape.shape = box
		shape.position.y = height * 0.5
		body.add_child(shape)
		add_child(body)
		body.position = _body_position(_home[i])
		_bodies.append(body)
	objects_reset.emit()


func _on_run_started(_run_index: int) -> void:
	reset()


func _body_position(cell: Vector2i) -> Vector3:
	return map_loader.cell_to_world(cell)


## The idle object the movement input presses against, as (id, dir.x, dir.y); id -1 when there is none. The input
## direction decides the axis; when two neighbouring objects qualify, the axis with the stronger input wins.
func _pressed_object() -> Vector3i:
	var intent: Vector3 = player.move_intent
	var world: WorldConfig = map_loader.world_config
	var half: float = world.cell_size * world.object_collision_ratio * 0.5
	var reach: float = half + player.config.body_radius + config.contact_margin
	var best: Vector3i = Vector3i(-1, 0, 0)
	var best_score: float = 0.0
	for id in _cells.size():
		if _busy[id] > 0.0:
			continue
		var offset: Vector3 = map_loader.cell_to_world(_cells[id]) - player.global_position
		for axis in 2:
			var strength: float = intent.x if axis == 0 else intent.z
			if absf(strength) < config.min_intent:
				continue
			var sign_s: float = signf(strength)
			var along: float = (offset.x if axis == 0 else offset.z) * sign_s
			var lateral: float = absf(offset.z if axis == 0 else offset.x)
			if along <= 0.0 or along > reach or lateral > half + config.lateral_tolerance:
				continue
			if absf(strength) > best_score:
				best_score = absf(strength)
				var step: int = int(sign_s)
				best = Vector3i(id, step, 0) if axis == 0 else Vector3i(id, 0, step)
	return best
