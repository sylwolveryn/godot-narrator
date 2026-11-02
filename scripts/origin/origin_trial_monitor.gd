class_name OriginTrialMonitor
extends Node
## Evaluates the origin trials (task-041) from signals the game already emits and says upward when one passed:
## SignalBus.origin_trial_passed(nature); OriginLedger answers with the strike (per-run cap, saved at once).
##  - demonic (EROSION_ESCAPE): erosion reached `erosion_fraction`, the player left the corruption (erosion falls),
##    and stayed alive `seconds` without eroding again.
##  - ai (SINGLE_FORM_SURVIVE): the single form was CHOSEN (animated entity_form_changed) and held `seconds`
##    alive in the same run.
##  - angelic (DARK_IDLE): idle for `seconds` on a cell at least `distance` cells from every light-source cell.
##  - alien (OBJECT_MOVED): dormant until task-045.
## A trial only runs while its nature is alive and armed. Seconds are multiplied by OriginLedger.trial_scale(id)
## (harder after recants). Reads only; it never writes the ledger state. Per-frame work only while a timer runs.

@export var ledger: OriginLedger
@export var run_manager: RunManager
## Read-only: where the player stands (angelic distance check).
@export var player: Node3D
@export var map_loader: MapLoader

const NOT_FOUND: int = -1

## Trial and nature id per OriginTrial.Kind (null / empty = no such trial in the config).
var _ids: Array[StringName] = []
var _trials: Array[OriginTrial] = []

## Nature ids that passed in this run (a passed trial reports once per run, even if the cap refuses the strike).
var _passed: Dictionary[StringName, bool] = {}

# demonic
var _erosion_reached: bool = false
var _erosion_left: bool = false
var _erosion_last: float = 0.0
var _erosion_clock: float = 0.0
# ai
var _single_chosen: bool = false
var _single_clock: float = 0.0
# angelic
var _idle: bool = false
var _idle_clock: float = 0.0
## -1 unknown (resolved on the first tick), 0 near a light, 1 far enough.
var _idle_far: int = -1

var _light_map: MapData
var _light_cells: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	_ids.resize(OriginTrial.Kind.size())
	_trials.resize(OriginTrial.Kind.size())
	if ledger != null and ledger.config != null:
		for h in ledger.config.hypotheses:
			if h != null and h.is_nature() and h.trial != null:
				_ids[h.trial.kind] = h.id
				_trials[h.trial.kind] = h.trial
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.run_ended.connect(_on_run_ended)
	SignalBus.erosion_changed.connect(_on_erosion_changed)
	SignalBus.entity_form_changed.connect(_on_form_changed)
	SignalBus.player_motion_changed.connect(_on_motion_changed)
	SignalBus.origin_ledger_changed.connect(_on_ledger_changed)
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


## Advances the running timers by `delta` seconds (called every frame while one runs; tests call it directly).
func advance(delta: float) -> void:
	if not _playing():
		return
	if _running(OriginTrial.Kind.EROSION_ESCAPE) and _erosion_reached and _erosion_left:
		_erosion_clock += delta
		_check(OriginTrial.Kind.EROSION_ESCAPE, _erosion_clock)
	if _running(OriginTrial.Kind.SINGLE_FORM_SURVIVE) and _single_chosen:
		_single_clock += delta
		_check(OriginTrial.Kind.SINGLE_FORM_SURVIVE, _single_clock)
	if _running(OriginTrial.Kind.DARK_IDLE) and _idle:
		if _idle_far == NOT_FOUND:
			_idle_far = 1 if _is_far_from_lights(_trials[OriginTrial.Kind.DARK_IDLE].distance) else 0
		if _idle_far == 1:
			_idle_clock += delta
			_check(OriginTrial.Kind.DARK_IDLE, _idle_clock)
	_refresh_processing()


# --- Signals ---------------------------------------------------------------------------------------------------

func _on_run_started(_run_index: int) -> void:
	_reset_run_state()
	# The player starts still; the idle clock begins with the run.
	_idle = true
	_refresh_processing()


func _on_run_ended(_cause: StringName) -> void:
	_reset_run_state()
	_refresh_processing()


func _on_erosion_changed(amount: float, _tint: Color) -> void:
	var kind: int = OriginTrial.Kind.EROSION_ESCAPE
	var rising: bool = amount > _erosion_last
	var falling: bool = amount < _erosion_last
	_erosion_last = amount
	if not _playing() or not _active(kind):
		return
	if rising:
		# Eroding again: the escape has to start over.
		_erosion_left = false
		_erosion_clock = 0.0
		if amount >= _trials[kind].erosion_fraction:
			_erosion_reached = true
	elif falling and _erosion_reached and not _erosion_left:
		_erosion_left = true
		_erosion_clock = 0.0
	_refresh_processing()


## The single form counts only when it was chosen (animate = true); the restore at run start is not a choice.
func _on_form_changed(form: StringName, animate: bool) -> void:
	if not animate:
		return
	_single_chosen = form == EntityForm.SINGLE and _active_or_dormant(OriginTrial.Kind.SINGLE_FORM_SURVIVE)
	_single_clock = 0.0
	_refresh_processing()


func _on_motion_changed(moving: bool) -> void:
	_idle = not moving
	_idle_clock = 0.0
	_idle_far = NOT_FOUND
	_refresh_processing()


func _on_ledger_changed(_alive: PackedStringArray, _struck: PackedStringArray) -> void:
	_refresh_processing()


# --- Internals -------------------------------------------------------------------------------------------------

func _reset_run_state() -> void:
	_passed.clear()
	_erosion_reached = false
	_erosion_left = false
	_erosion_last = 0.0
	_erosion_clock = 0.0
	_single_chosen = false
	_single_clock = 0.0
	_idle = false
	_idle_clock = 0.0
	_idle_far = NOT_FOUND


func _playing() -> bool:
	return run_manager != null and run_manager.phase == RunManager.Phase.PLAYING


## True when the trial of that kind exists, its nature is alive and armed, and it did not pass in this run.
func _active(kind: int) -> bool:
	return _active_or_dormant(kind) and ledger.is_armed(_ids[kind])


## The trial exists and its nature is alive and has not passed this run (armed or not: a claim may arrive after the
## precondition, e.g. the form switch that also plays the ai claim).
func _active_or_dormant(kind: int) -> bool:
	return _trials[kind] != null and ledger != null and ledger.is_alive(_ids[kind]) and not _passed.has(_ids[kind])


## Whether the timer of that kind may tick now.
func _running(kind: int) -> bool:
	return _active(kind)


func _check(kind: int, clock: float) -> void:
	var id: StringName = _ids[kind]
	if clock < _trials[kind].seconds * ledger.trial_scale(id):
		return
	_passed[id] = true
	SignalBus.origin_trial_passed.emit(id)


## Processing is on only while a timer can tick.
func _refresh_processing() -> void:
	var wanted: bool = false
	if _playing():
		wanted = (_running(OriginTrial.Kind.EROSION_ESCAPE) and _erosion_reached and _erosion_left) \
				or (_running(OriginTrial.Kind.SINGLE_FORM_SURVIVE) and _single_chosen) \
				or (_running(OriginTrial.Kind.DARK_IDLE) and _idle and _idle_far != 0)
	if wanted != is_processing():
		set_process(wanted)


## True when the player's cell is at least `min_cells` from every light-source cell (item, spikes, corruption).
func _is_far_from_lights(min_cells: int) -> bool:
	if player == null or map_loader == null or map_loader.data == null:
		return false
	if _light_map != map_loader.data:
		_collect_light_cells(map_loader.data)
	var here := Vector2(map_loader.world_to_cell(player.global_position))
	var limit: float = float(min_cells * min_cells)
	for cell in _light_cells:
		if here.distance_squared_to(cell) < limit:
			return false
	return true


func _collect_light_cells(map: MapData) -> void:
	_light_map = map
	_light_cells = PackedVector2Array()
	for y in map.height:
		for x in map.width:
			var type: StringName = map.type_at(Vector2i(x, y))
			if type == MapLegend.ITEM or type == MapLegend.SPIKES or type == MapLegend.CORRUPT:
				_light_cells.append(Vector2(x, y))
