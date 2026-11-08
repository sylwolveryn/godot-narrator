class_name HazardMonitor
extends Node
## Watches the player against the hazard cells of the loaded map and asks for a run end.
##  - Spikes (lethal_on_touch): touching ends the run at once.
##  - Corrupting glyphs: erosion rises while inside, recovers outside, ends the run at the threshold.
## Hazards are lethal whether or not they have been revealed. Only acts while the run is PLAYING
## and requests the end at most once per run. Erosion is kept in RunState (per run) and announced
## upward through SignalBus.erosion_changed; presentation never writes it.

@export var map_loader: MapLoader
@export var player: Player
## Read-only source of the run phase and the per-run state.
@export var run_manager: RunManager

## Set once the end was requested, so a run can never be ended twice by hazards.
var _fired: bool = false
var _active: HazardDefinition
var _last_announced: float = -1.0
var _entered_corruption: bool = false


func _ready() -> void:
	SignalBus.run_started.connect(_on_run_started)


func _physics_process(delta: float) -> void:
	if _fired or player == null or map_loader == null or run_manager == null:
		return
	if run_manager.phase != RunManager.Phase.PLAYING:
		return
	var def: HazardDefinition = hazard_at(player.global_position)
	if def != null and def.lethal_on_touch:
		_kill(def)
		return
	var state: RunState = run_manager.state
	if def != null and def.erosion_rate > 0.0:
		_active = def
		state.erosion += def.erosion_rate * delta
		_announce_entry()
	elif state.erosion > 0.0:
		var recovery: float = _active.recovery_rate if _active != null else 0.0
		state.erosion = maxf(0.0, state.erosion - recovery * delta)
	_announce(state.erosion)
	if _active != null and state.erosion >= _active.erosion_threshold:
		_kill(_active)


## Hazard definition under a world position, or null when the cell is not a hazard.
func hazard_at(world_position: Vector3) -> HazardDefinition:
	var cell: Vector2i = map_loader.world_to_cell(world_position)
	return map_loader.legend.hazards.get(map_loader.data.type_at(cell))


func _kill(def: HazardDefinition) -> void:
	_fired = true
	if def.lethal_on_touch:
		SignalBus.narration_event.emit(NarrationEvents.HIT_SPIKES)
	SignalBus.hazard_lethal.emit(def.end_cause, def.tint)
	SignalBus.run_end_requested.emit(def.end_cause)


## Announces erosion as a 0..1 fraction of the active threshold, only when it changed.
func _announce(erosion: float) -> void:
	if _active == null or erosion == _last_announced:
		return
	_last_announced = erosion
	SignalBus.erosion_changed.emit(clampf(erosion / _active.erosion_threshold, 0.0, 1.0), _active.tint)


func _on_run_started(_run_index: int) -> void:
	_fired = false
	_active = null
	_entered_corruption = false
	if _last_announced != 0.0:
		_last_announced = 0.0
		SignalBus.erosion_changed.emit(0.0, Color.WHITE)


## Narration: the first time this run the player stands in a corrupting area.
func _announce_entry() -> void:
	if _entered_corruption:
		return
	_entered_corruption = true
	SignalBus.narration_event.emit(NarrationEvents.CORRUPTION_ENTERED)
