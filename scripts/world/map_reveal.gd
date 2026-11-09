class_name MapReveal
extends Node
## Hides the built map at the start of every run and reveals it around the player.
##  - Cells never seen are hidden.
##  - Cells seen in earlier runs (PersistentProgress.revealed_cells) show in the memory style.
##  - Cells within RevealConfig.reveal_radius of the player that are in its line of sight (SightLine: walls and items
##    hide what is behind them) show normally and stay so for the run.
## Cells seen for the first time ever are announced upward via SignalBus.cells_revealed;
## SaveService records them. This node only reads persistent data.
##
## Presentation: the look of every cell lives in a small mask texture (one texel per map cell,
## the global shader parameter `reveal_mask`) read by the glyph-surface shader:
##   r = reveal brightness / 1.25 (grows from 0 with an overshoot, staggered by distance),
##   g = seen fraction (0 = remembered, 1 = seen; a remembered cell turns into a seen one over
##       RevealConfig.memory_to_seen_duration), b = cyan glint at RevealConfig.reveal_glint_at,
##   a = 1 when the floor of the cell may be shown (RevealConfig.reveal_floor), else 0.
## The world is one merged mesh, so nothing is shown or hidden per node: a cell with r = 0 draws nothing.
## Per-map rules (task-069, MapSettings from the DB table map_settings): the reveal radius and line of sight, and
## `reveal_all` (every drawn cell is seen from the start of each run, no memory look). Without a row: RevealConfig.

## Emitted when cells were seen for the first time this run (the presentation re-picks its static lights).
signal cells_seen

## Maps already announced as fully discovered (task-091), so the announcement is made once.
var _complete_announced: Dictionary[StringName, bool] = {}

enum CellState { HIDDEN, MEMORY, SEEN }

## Largest brightness the mask can hold (r is stored divided by this).
const MASK_BRIGHTNESS_MAX := 1.25
## Width of the glint bump, as a fraction of the reveal.
const GLINT_WIDTH := 0.12
const MASK_PARAM := &"reveal_mask"

@export var config: RevealConfig
@export var map_loader: MapLoader
@export var player: Player
@export var save_service: SaveService
## Optional (task-069): the per-map visibility rules. Without it RevealConfig alone decides.
@export var settings: MapSettingsResolver

## Rules of the loaded map, resolved over `config` at every begin_run and DB reload.
var map_settings: MapSettings = MapSettings.new()

## Cells seen during the current run.
var seen_this_run: Dictionary[Vector2i, bool] = {}

var _remembered: Dictionary[Vector2i, bool] = {}
## Becomes true when the player is placed for a run; false again when the run ends.
var _tracking: bool = false
var _last_position: Vector3 = Vector3.INF
## Reveal events already announced this run.
var _announced: Dictionary[StringName, bool] = {}

var _size: Vector2i = Vector2i.ZERO
var _brightness: PackedFloat32Array = PackedFloat32Array()
var _seen: PackedFloat32Array = PackedFloat32Array()
var _glint: PackedFloat32Array = PackedFloat32Array()
var _mask: Image
var _mask_texture: ImageTexture
var _dirty: bool = false
var _clock: float = 0.0
## Running cell animations: cell -> [start time, from_memory (bool)].
var _animations: Dictionary[Vector2i, Array] = {}
## Sight blockers of the loaded map: RevealConfig.sight_blockers plus the large prop types that block sight (task-058).
var _blockers: Array[StringName] = []
## Scratch list of the animations that finished in this step (reused, no per-frame allocation).
var _finished: Array[Vector2i] = []


func _ready() -> void:
	if config == null:
		config = RevealConfig.new()
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.run_ended.connect(_on_run_ended)
	SignalBus.player_spawned.connect(_on_player_spawned)
	SignalBus.dirt_destroyed.connect(_on_dirt_destroyed)
	SignalBus.dev_reveal_map_requested.connect(_on_dev_reveal_map_requested)
	SignalBus.destructible_destroyed.connect(func(_k: StringName, _r: Rect2i, _w: Vector3, _c: StringName) -> void:
		_last_position = Vector3.INF)
	if settings != null:
		settings.settings_changed.connect(_on_settings_changed)
	if map_loader != null:
		map_loader.map_built.connect(_on_map_built)
		if not map_loader.data.is_empty():
			begin_run()


func _process(delta: float) -> void:
	_clock += delta
	if not _animations.is_empty():
		_step_animations()
	if _dirty:
		_flush()


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


## Presentation values of a cell: x = brightness (0 hidden, 1 shown, overshoots while revealing),
## y = seen fraction (0 remembered, 1 seen), z = glint.
func cell_look(cell: Vector2i) -> Vector3:
	var i: int = _index(cell)
	if i < 0:
		return Vector3.ZERO
	return Vector3(_brightness[i], _seen[i], _glint[i])


## The raw mask texel of a cell, exactly what the shader reads (see the class comment for the channels).
func mask_at(cell: Vector2i) -> Color:
	if _index(cell) < 0:
		return Color(0.0, 0.0, 0.0, 0.0)
	return _mask.get_pixel(cell.x, cell.y)


## True while a cell is still animating its reveal or its memory-to-seen change.
func is_animating(cell: Vector2i) -> bool:
	return _animations.has(cell)


## Resets to the run-start picture: only remembered cells show, in the memory style.
func begin_run() -> void:
	seen_this_run.clear()
	_announced.clear()
	_remembered.clear()
	_animations.clear()
	_last_position = Vector3.INF
	_resolve_settings()
	if map_loader == null:
		return
	_resize_mask(Vector2i(map_loader.data.width, map_loader.data.height))
	_blockers = config.sight_blockers.duplicate()
	if map_loader.legend != null:
		for type in map_loader.legend.sight_blocking_types():
			if not _blockers.has(type):
				_blockers.append(type)
	if save_service != null:
		var stored: PackedVector2Array = save_service.get_revealed_cells(map_loader.map_id)
		for v in stored:
			_remembered[Vector2i(int(v.x), int(v.y))] = true
	for cell: Vector2i in map_loader.drawn_cells:
		var state: CellState = state_of(cell)
		_set_look(cell, 1.0 if state == CellState.MEMORY else 0.0, 0.0, 0.0)
	if map_settings.reveal_all:
		reveal_all()
	_flush()


## Shows every drawn cell as seen at once (no animation, no memory look), announcing what it shows like a normal reveal.
func reveal_all() -> void:
	if map_loader == null:
		return
	var fresh := PackedVector2Array()
	for cell: Vector2i in map_loader.drawn_cells:
		if seen_this_run.has(cell):
			continue
		seen_this_run[cell] = true
		_animations.erase(cell)
		_set_look(cell, 1.0, 1.0, 0.0)
		_announce_kind(cell)
		if not _remembered.has(cell):
			_remembered[cell] = true
			fresh.append(Vector2(cell))
	cells_seen.emit()
	if not fresh.is_empty():
		SignalBus.cells_revealed.emit(map_loader.map_id, fresh)
		_check_complete()


## Reveals every cell whose centre is within the reveal radius of a world position.
func reveal_around(world_position: Vector3) -> void:
	if map_settings.reveal_all:
		return
	var size: float = map_loader.world_config.cell_size
	var reach: float = map_settings.reveal_radius * size
	var centre: Vector2i = map_loader.world_to_cell(world_position)
	var span: int = ceili(map_settings.reveal_radius) + 1
	var fresh := PackedVector2Array()
	var any_seen: bool = false
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var cell := centre + Vector2i(dx, dy)
			if seen_this_run.has(cell) or not map_loader.is_drawn(cell):
				continue
			var cell_centre: Vector3 = map_loader.cell_to_world(cell)
			var distance: float = Vector2(cell_centre.x - world_position.x, cell_centre.z - world_position.z).length()
			if distance > reach:
				continue
			if map_settings.line_of_sight and not SightLine.can_see(map_loader.data, centre, cell, _blockers if not _blockers.is_empty() else config.sight_blockers, config.sight_spread):
				continue
			var from_memory: bool = _remembered.has(cell)
			seen_this_run[cell] = true
			any_seen = true
			_start_animation(cell, from_memory, distance / size)
			_announce_kind(cell)
			if not from_memory:
				_remembered[cell] = true
				fresh.append(Vector2(cell))
	if any_seen:
		cells_seen.emit()
	if not fresh.is_empty():
		SignalBus.cells_revealed.emit(map_loader.map_id, fresh)
		_check_complete()


func _on_run_started(_run_index: int) -> void:
	begin_run()


## The player was just placed at the spawn: reveal its surroundings right away.
func _on_player_spawned(world_position: Vector3) -> void:
	if map_loader == null:
		return
	_tracking = true
	_last_position = world_position
	reveal_around(world_position)


## god's Reveal map (via DevBridge): show every cell of the loaded map now; the fresh ones are saved as remembered.
func _on_dev_reveal_map_requested() -> void:
	if map_loader == null or map_loader.data.is_empty():
		return
	reveal_all()
	_flush()


func _on_run_ended(_cause: StringName) -> void:
	_tracking = false


func _on_map_built(_data: MapData) -> void:
	begin_run()


func _resolve_settings() -> void:
	map_settings = MapSettings.resolve(settings.current_row() if settings != null else {}, config, null)


## The DB was reloaded: new radius / sight rules apply from the next move; a map that became reveal_all shows at once.
func _on_settings_changed() -> void:
	_resolve_settings()
	if map_settings.reveal_all and map_loader != null and not map_loader.data.is_empty():
		reveal_all()
		_flush()
	_last_position = Vector3.INF


## A dirt cell opened (task-070): what lies behind it may be in sight now, so the next physics step reveals again.
func _on_dirt_destroyed(_map_id: StringName, _cell: Vector2i, _cause: StringName) -> void:
	_last_position = Vector3.INF


## Task-091: when every drawn cell of the map is remembered, SignalBus.map_fully_revealed (once per map per launch).
func _check_complete() -> void:
	if map_loader == null or _complete_announced.has(map_loader.map_id):
		return
	if _remembered.size() < map_loader.drawn_cells.size():
		return
	for cell: Vector2i in map_loader.drawn_cells:
		if not _remembered.has(cell):
			return
	_complete_announced[map_loader.map_id] = true
	SignalBus.map_fully_revealed.emit(map_loader.map_id)


## Announces, once per run, the first revealed cell of each type that has a narration event.
func _announce_kind(cell: Vector2i) -> void:
	var event: StringName = config.reveal_events.get(map_loader.data.type_at(cell), &"")
	if event == &"" or _announced.has(event):
		return
	_announced[event] = true
	SignalBus.narration_event.emit(event)


func _index(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= _size.x or cell.y >= _size.y:
		return -1
	return cell.y * _size.x + cell.x


func _resize_mask(size: Vector2i) -> void:
	size = Vector2i(maxi(size.x, 1), maxi(size.y, 1))
	if size != _size or _mask == null:
		_size = size
		_mask = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		_mask_texture = ImageTexture.create_from_image(_mask)
		RenderingServer.global_shader_parameter_set(MASK_PARAM, _mask_texture)
	var count: int = size.x * size.y
	_brightness.resize(count)
	_seen.resize(count)
	_glint.resize(count)
	_brightness.fill(0.0)
	_seen.fill(0.0)
	_glint.fill(0.0)
	_mask.fill(Color(0.0, 0.0, 0.0, 1.0 if config.reveal_floor else 0.0))
	_dirty = true


func _set_look(cell: Vector2i, brightness: float, seen: float, glint: float) -> void:
	var i: int = _index(cell)
	if i < 0:
		return
	_brightness[i] = brightness
	_seen[i] = seen
	_glint[i] = glint
	var encoded := Color(clampf(brightness / MASK_BRIGHTNESS_MAX, 0.0, 1.0), clampf(seen, 0.0, 1.0), clampf(glint, 0.0, 1.0), 1.0 if config.reveal_floor else 0.0)
	_mask.set_pixel(cell.x, cell.y, encoded)
	_dirty = true


func _flush() -> void:
	_dirty = false
	_mask_texture.update(_mask)


## A cell that has just been seen: it waits for its stagger delay (distance in cells from the
## player), then animates. Until then it holds its starting look (dark, or still remembered).
func _start_animation(cell: Vector2i, from_memory: bool, distance_cells: float) -> void:
	var start: float = _clock + distance_cells * config.reveal_stagger_per_cell
	_animations[cell] = [start, from_memory]
	if from_memory:
		_set_look(cell, 1.0, 0.0, 0.0)
	else:
		_set_look(cell, 0.0, 1.0, 0.0)


func _step_animations() -> void:
	_finished.clear()
	for cell: Vector2i in _animations:
		var entry: Array = _animations[cell]
		var start: float = entry[0]
		var from_memory: bool = entry[1]
		var duration: float = config.memory_to_seen_duration if from_memory else config.reveal_duration
		var p: float = (_clock - start) / maxf(duration, 0.001)
		if p < 0.0:
			continue
		if p >= 1.0:
			_set_look(cell, 1.0, 1.0, 0.0)
			_finished.append(cell)
			continue
		if from_memory:
			_set_look(cell, 1.0, smoothstep(0.0, 1.0, p), 0.0)
		else:
			var grow: float = smoothstep(0.0, 1.0, p)
			var overshoot: float = 1.0 + (config.reveal_overshoot - 1.0) * sin(PI * p)
			var glint: float = exp(-pow((p - config.reveal_glint_at) / GLINT_WIDTH, 2.0))
			_set_look(cell, grow * overshoot, 1.0, glint)
	for cell in _finished:
		_animations.erase(cell)
