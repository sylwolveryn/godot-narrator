class_name MapReveal
extends Node
## Hides the built map at the start of every run and reveals it around the player.
##  - Cells never seen are hidden.
##  - Cells seen in earlier runs (PersistentProgress.revealed_cells) show in the memory style.
##  - Cells within RevealConfig.reveal_radius of the player show normally and stay so for the run.
## Cells seen for the first time ever are announced upward via SignalBus.cells_revealed;
## SaveService records them. This node only reads persistent data.

enum CellState { HIDDEN, MEMORY, SEEN }

@export var config: RevealConfig
@export var map_loader: MapLoader
@export var player: Player
@export var save_service: SaveService

## Cells seen during the current run.
var seen_this_run: Dictionary[Vector2i, bool] = {}

var _remembered: Dictionary[Vector2i, bool] = {}
var _memory_materials: Dictionary[StringName, StandardMaterial3D] = {}
## Becomes true when the player is placed for a run; false again when the run ends.
var _tracking: bool = false
var _last_position: Vector3 = Vector3.INF
## Reveal events already announced this run.
var _announced: Dictionary[StringName, bool] = {}


func _ready() -> void:
	if config == null:
		config = RevealConfig.new()
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.run_ended.connect(_on_run_ended)
	SignalBus.player_spawned.connect(_on_player_spawned)
	if map_loader != null:
		map_loader.map_built.connect(_on_map_built)
		if not map_loader.data.is_empty():
			begin_run()


func _physics_process(_delta: float) -> void:
	if not _tracking or player == null or map_loader == null:
		return
	if player.global_position == _last_position:
		return
	_last_position = player.global_position
	reveal_around(_last_position)


## State of a cell right now.
func state_of(cell: Vector2i) -> CellState:
	if seen_this_run.has(cell):
		return CellState.SEEN
	if _remembered.has(cell):
		return CellState.MEMORY
	return CellState.HIDDEN


## Resets to the run-start picture: only remembered cells show, in the memory style.
func begin_run() -> void:
	seen_this_run.clear()
	_announced.clear()
	_remembered.clear()
	_last_position = Vector3.INF
	if map_loader == null:
		return
	_build_memory_materials()
	if save_service != null:
		var stored: PackedVector2Array = save_service.get_revealed_cells(map_loader.map_id)
		for v in stored:
			_remembered[Vector2i(int(v.x), int(v.y))] = true
	for cell: Vector2i in map_loader.visuals:
		_apply(cell, state_of(cell))


## Reveals every cell whose centre is within the reveal radius of a world position.
func reveal_around(world_position: Vector3) -> void:
	var size: float = map_loader.world_config.cell_size
	var reach: float = config.reveal_radius * size
	var centre: Vector2i = map_loader.world_to_cell(world_position)
	var span: int = ceili(config.reveal_radius) + 1
	var fresh := PackedVector2Array()
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var cell := centre + Vector2i(dx, dy)
			if seen_this_run.has(cell) or not map_loader.visuals.has(cell):
				continue
			var cell_centre: Vector3 = map_loader.cell_to_world(cell)
			if Vector2(cell_centre.x - world_position.x, cell_centre.z - world_position.z).length() > reach:
				continue
			seen_this_run[cell] = true
			_apply(cell, CellState.SEEN)
			_announce_kind(cell)
			if not _remembered.has(cell):
				_remembered[cell] = true
				fresh.append(Vector2(cell))
	if not fresh.is_empty():
		SignalBus.cells_revealed.emit(map_loader.map_id, fresh)


func _on_run_started(_run_index: int) -> void:
	begin_run()


## The player was just placed at the spawn: reveal its surroundings right away.
func _on_player_spawned(world_position: Vector3) -> void:
	if map_loader == null:
		return
	_tracking = true
	_last_position = world_position
	reveal_around(world_position)


func _on_run_ended(_cause: StringName) -> void:
	_tracking = false


func _on_map_built(_data: MapData) -> void:
	begin_run()


func _apply(cell: Vector2i, state: CellState) -> void:
	for mesh: MeshInstance3D in map_loader.visuals_at(cell):
		var kind: StringName = mesh.get_meta(&"kind", &"")
		if kind == MapLegend.FLOOR and not config.reveal_floor:
			mesh.visible = false
			continue
		match state:
			CellState.HIDDEN:
				mesh.visible = false
			CellState.MEMORY:
				mesh.visible = true
				mesh.material_override = _memory_materials.get(kind)
			CellState.SEEN:
				mesh.visible = true
				mesh.material_override = null


func _build_memory_materials() -> void:
	var world: WorldConfig = map_loader.world_config
	var colors: Dictionary[StringName, Color] = {
		MapLegend.FLOOR: world.floor_color,
		MapLegend.WALL: world.wall_color,
		MapLegend.ITEM: world.item_color,
		MapLegend.SPIKES: world.spike_color,
		MapLegend.CORRUPT: world.corrupt_color,
	}
	_memory_materials.clear()
	for kind: StringName in colors:
		var base: Color = colors[kind]
		var grey: float = base.get_luminance()
		var dull: Color = base.lerp(Color(grey, grey, grey), config.memory_desaturation) * config.memory_brightness
		dull.a = 1.0
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = dull
		_memory_materials[kind] = mat


## Announces, once per run, the first revealed cell of each type that has a narration event.
func _announce_kind(cell: Vector2i) -> void:
	var event: StringName = config.reveal_events.get(map_loader.data.type_at(cell), &"")
	if event == &"" or _announced.has(event):
		return
	_announced[event] = true
	SignalBus.narration_event.emit(event)
