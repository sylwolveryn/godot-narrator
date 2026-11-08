class_name LargeObjects
extends Node
## Data layer of the merged multi-cell props (task-073): the only writer of their destroyed state. A prop whose
## LargeObjectDef.destructible is set (the gargoyle fountain) opts into Destructibles under its type; destroying it
## removes the WHOLE merged object: its cells become floor (sight and light follow the map data), its collision box is
## switched off, LargeObjectView hides it (SignalBus.destructible_destroyed). Destroyed props come back at every run
## start (SignalBus.destructible_restored), like dirt. Indestructible props (cannons) never register.

@export var map_loader: MapLoader
@export var destructibles: Destructibles

## Destroyed placements, in destruction order.
var _destroyed: Array[LargeObjectPlacement] = []


func _ready() -> void:
	SignalBus.run_started.connect(func(_i: int) -> void: restore())
	if map_loader != null:
		map_loader.map_built.connect(_on_map_built)
		if not map_loader.data.is_empty():
			_on_map_built(map_loader.data)


## True when `cell` belongs to a standing destructible prop.
func is_destructible_at(cell: Vector2i) -> bool:
	var p: LargeObjectPlacement = map_loader.data.large_object_at(cell) if map_loader != null else null
	return p != null and _def(p) != null and _def(p).destructible


## Number of destroyed props right now.
func destroyed_count() -> int:
	return _destroyed.size()


## Destroys the destructible prop covering `cell`. Returns false when there is none.
func destroy(cell: Vector2i, cause: StringName) -> bool:
	if not is_destructible_at(cell):
		return false
	var p: LargeObjectPlacement = map_loader.data.large_object_at(cell)
	p.destroyed = true
	_destroyed.append(p)
	_set_cells(p, MapLegend.FLOOR)
	_set_collision(p, false)
	SignalBus.destructible_destroyed.emit(p.type, p.rect, map_loader.rect_to_world(p.rect), cause)
	return true


## Every destroyed prop stands again (run start).
func restore() -> void:
	if map_loader == null:
		return
	var back: Array[LargeObjectPlacement] = _destroyed.duplicate()
	_destroyed.clear()
	for p in back:
		p.destroyed = false
		_set_cells(p, p.type)
		_set_collision(p, true)
		SignalBus.destructible_restored.emit(p.type, p.rect)


func _on_map_built(map: MapData) -> void:
	_destroyed.clear()
	if destructibles == null or map_loader.legend == null:
		return
	var registered: Dictionary[StringName, bool] = {}
	for p in map.large_objects:
		var def: LargeObjectDef = _def(p)
		if def != null and def.destructible and not registered.has(p.type):
			registered[p.type] = true
			var type: StringName = p.type
			destructibles.register(type, func(cell: Vector2i) -> bool:
				return is_destructible_at(cell) and map_loader.data.large_object_at(cell).type == type, destroy)


func _def(p: LargeObjectPlacement) -> LargeObjectDef:
	return map_loader.legend.large_def(p.type) if map_loader.legend != null else null


func _set_cells(p: LargeObjectPlacement, type: StringName) -> void:
	for y in range(p.rect.position.y, p.rect.end.y):
		for x in range(p.rect.position.x, p.rect.end.x):
			map_loader.data.set_type(Vector2i(x, y), type)


func _set_collision(p: LargeObjectPlacement, on: bool) -> void:
	var body: StaticBody3D = map_loader.large_body(p)
	if body == null:
		return
	for child in body.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred(&"disabled", not on)
