class_name TeleportSystem
extends Node
## Teleports (task-068), logic side. Watches the player's cell; stepping onto a working pad's centre starts a trip to
## one random pad of the next higher channel present on the map (TeleportPad.targets). The trip is a fixed timeline of
## TeleportConfig.trip_seconds: SignalBus.teleport_started at once (movement and the menu block), the body is moved to
## the destination centre `arrival_seconds` before the end (teleport_arrived), teleport_finished at the end. After
## arriving (or when a pad has nowhere to go) that pad cannot fire again until the player has left its centre.
## The only writer of the trip state; presentation (TeleportView, PlayerGlyphView) follows the signals.

@export var config: TeleportConfig
@export var map_loader: MapLoader
@export var player: Player
## Read-only source of the run phase (trips only start while playing).
@export var run_manager: RunManager

## Destination picker; tests seed it.
var rng := RandomNumberGenerator.new()

var _active: bool = false
var _arrived: bool = false
var _t: float = 0.0
var _from: int = -1
var _dest: int = -1
var _candidates: Array[int] = []
## Pad whose centre must be left before it can fire again (-1 = none).
var _blocked: int = -1


func _ready() -> void:
	if config == null:
		config = TeleportConfig.new()
	rng.randomize()
	SignalBus.run_started.connect(_on_run_changed)
	SignalBus.run_ended.connect(_on_run_changed)


func _physics_process(delta: float) -> void:
	if player == null or map_loader == null:
		return
	if _active:
		_step(delta)
		return
	var pad: int = map_loader.data.teleport_at_centre(map_loader.world_to_cell(player.global_position))
	if pad < 0:
		_blocked = -1
		return
	if pad == _blocked or not _playing():
		return
	start_trip(pad)


## True while a trip runs.
func is_active() -> bool:
	return _active


## Seconds since the running trip started (0 when none runs).
func elapsed() -> float:
	return _t if _active else 0.0


## Pad indices (MapData.teleports) of the running or last trip: source, candidates, destination.
func source_pad() -> int:
	return _from


func candidate_pads() -> Array[int]:
	return _candidates


func destination_pad() -> int:
	return _dest


## Starts a trip from pad `from` (MapData.teleports index). Returns false when the pad has nowhere to go (then it is
## blocked until left) or a trip already runs.
func start_trip(from: int) -> bool:
	if _active:
		return false
	var pads: Array[TeleportPad] = map_loader.data.teleports
	var targets: Array[int] = TeleportPad.targets(pads, from)
	_blocked = from
	if targets.is_empty():
		return false
	_from = from
	_candidates = targets
	var chosen: int = rng.randi_range(0, targets.size() - 1)
	_dest = targets[chosen]
	_active = true
	_arrived = false
	_t = 0.0
	var centres: Array[Vector3] = []
	for i in targets:
		centres.append(map_loader.cell_to_world(pads[i].centre))
	SignalBus.teleport_started.emit(map_loader.cell_to_world(pads[from].centre), centres, chosen, config.trip_seconds)
	return true


func _step(delta: float) -> void:
	_t += delta
	if not _arrived and _t >= config.trip_seconds - config.arrival_seconds:
		_arrived = true
		var centre: Vector3 = map_loader.cell_to_world(map_loader.data.teleports[_dest].centre)
		player.place_at(centre)
		_blocked = _dest
		SignalBus.teleport_arrived.emit(centre, _candidates.size())
	if _t >= config.trip_seconds:
		_active = false
		SignalBus.teleport_finished.emit()


func _playing() -> bool:
	return run_manager == null or run_manager.phase == RunManager.Phase.PLAYING


## A new run or the end of one cuts a running trip short (the spawn places the body anew).
func _on_run_changed(_value: Variant) -> void:
	_blocked = -1
	if _active:
		_active = false
		SignalBus.teleport_finished.emit()
