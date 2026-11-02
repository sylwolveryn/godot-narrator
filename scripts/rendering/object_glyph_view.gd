class_name ObjectGlyphView
extends Node3D
## Draws the small pushable objects (task-019): ONE MultiMeshInstance3D with the glyph-surface material (stone blocks
## built by WorldMeshBuilder.build_object), one instance per object, so the merged static world mesh never changes. The
## shader derives the map cell (reveal mask) from the instance origin. A push slides the
## instance from its cell to the next with an eased animation; the only per-frame work is the transform of the sliding
## instances. Reads PushableObjects and SignalBus.object_moved; never writes data.

@export var pushables: PushableObjects
@export var map_loader: MapLoader
@export var config: PushConfig

var _multimesh: MultiMesh
var _instance: MultiMeshInstance3D
## Active slides: object id -> [from_world, to_world, from_cell, to_cell, elapsed].
var _slides: Dictionary[int, Array] = {}
## Where each instance is drawn (mirror of the MultiMesh transforms, readable without a renderer).
var _positions: PackedVector3Array = PackedVector3Array()


func _ready() -> void:
	if config == null:
		config = PushConfig.new()
	set_process(false)
	SignalBus.object_moved.connect(_on_object_moved)
	if pushables != null:
		pushables.objects_reset.connect(_on_objects_reset)
		if pushables.count() > 0:
			_on_objects_reset()


func _process(delta: float) -> void:
	for id: int in _slides.keys():
		var slide: Array = _slides[id]
		slide[4] += delta
		var t: float = clampf(slide[4] / maxf(config.slide_duration, 0.001), 0.0, 1.0)
		var pos: Vector3 = (slide[0] as Vector3).lerp(slide[1] as Vector3, ease(t, config.slide_ease))
		_place(id, pos)
		if t >= 1.0:
			_slides.erase(id)
	if _slides.is_empty():
		set_process(false)


## Number of drawn objects.
func instance_count() -> int:
	return _multimesh.instance_count if _multimesh != null else 0


## World position the instance is drawn at (mid-slide positions included).
func position_of(id: int) -> Vector3:
	return _positions[id]


## True while at least one object slides.
func is_sliding() -> bool:
	return not _slides.is_empty()


func _on_objects_reset() -> void:
	_slides.clear()
	set_process(false)
	var world: WorldConfig = map_loader.world_config
	var count: int = pushables.count()
	if _instance == null:
		_multimesh = MultiMesh.new()
		_multimesh.transform_format = MultiMesh.TRANSFORM_3D
		_multimesh.mesh = WorldMeshBuilder.new().build_object(world)
		_instance = MultiMeshInstance3D.new()
		_instance.name = "Objects"
		_instance.multimesh = _multimesh
		_instance.material_override = map_loader.surface_material
		_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_instance)
	if _multimesh.instance_count != count:
		_multimesh.instance_count = count
	_positions.resize(count)
	_instance.visible = count > 0
	for id in count:
		var cell: Vector2i = pushables.cell_of(id)
		_place(id, map_loader.cell_to_world(cell))


func _on_object_moved(object_id: int, from_cell: Vector2i, to_cell: Vector2i, _form: StringName) -> void:
	if _multimesh == null or object_id >= _multimesh.instance_count:
		return
	_slides[object_id] = [map_loader.cell_to_world(from_cell), map_loader.cell_to_world(to_cell), from_cell, to_cell, 0.0]
	set_process(true)


func _place(id: int, pos: Vector3) -> void:
	_positions[id] = pos
	_multimesh.set_instance_transform(id, Transform3D(Basis.IDENTITY, pos))
