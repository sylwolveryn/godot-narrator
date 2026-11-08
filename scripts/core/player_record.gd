class_name PlayerRecord
extends Node
## Keeps the player's track record in the DB `player_*` tables (task-049): played time, steps, transformations and
## deaths by cause. Listens to SignalBus only; sends the counters to the GameDatabase every DbConfig.flush_seconds and
## when the run ends, deaths right away. Holds no game state (only not-yet-sent deltas).

@export var database: GameDatabase

## Not yet sent to the DB.
var pending_seconds: float = 0.0
var pending_steps: int = 0
var pending_transformations: int = 0

var _run_active: bool = false
var _flush_timer: float = 0.0


func _ready() -> void:
	SignalBus.run_started.connect(_on_run_started)
	SignalBus.run_ended.connect(_on_run_ended)
	SignalBus.player_stepped.connect(_on_player_stepped)
	SignalBus.entity_form_changed.connect(_on_entity_form_changed)


func _process(delta: float) -> void:
	if not _run_active:
		return
	pending_seconds += delta
	_flush_timer -= delta
	if _flush_timer <= 0.0:
		flush()


## Sends the collected counters (if any) and starts a new flush period.
func flush() -> void:
	_flush_timer = database.config.flush_seconds if database != null and database.config != null else 0.0
	if pending_seconds <= 0.0 and pending_steps == 0 and pending_transformations == 0:
		return
	if database != null:
		database.call_reducer("add_play_stats", [pending_seconds, pending_steps, pending_transformations])
	pending_seconds = 0.0
	pending_steps = 0
	pending_transformations = 0


func _on_run_started(_run_index: int) -> void:
	_run_active = true


func _on_run_ended(cause: StringName) -> void:
	_run_active = false
	flush()
	if database != null:
		database.call_reducer("record_death", [str(cause)])


func _on_player_stepped(_cell: Vector2i) -> void:
	pending_steps += 1


## Only a chosen switch is a transformation (animate = true).
func _on_entity_form_changed(_form: StringName, animate: bool) -> void:
	if animate:
		pending_transformations += 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()
