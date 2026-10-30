class_name RunManager
extends Node
## Sole owner of the run lifecycle: INTRO -> PLAYING -> DYING -> (restart) PLAYING.
## Others request a run end via SignalBus.run_end_requested or end_run().

enum Phase { INTRO, PLAYING, DYING }

@export var config: RunConfig

var phase: Phase = Phase.INTRO
var state: RunState = RunState.new()
## Number of runs started so far; also the index of the next run.
var run_count: int = 0


func _ready() -> void:
	if config == null:
		config = RunConfig.new()
	SignalBus.run_end_requested.connect(end_run)
	SignalBus.run_ended.connect(_on_run_ended)


func _process(delta: float) -> void:
	if phase == Phase.PLAYING:
		state.elapsed += delta


## Starts a run with a brand new RunState.
func start_run() -> void:
	state = RunState.new()
	state.run_index = run_count
	run_count += 1
	phase = Phase.PLAYING
	SignalBus.run_started.emit(state.run_index)


## Ends the current run. Ignored unless a run is in progress.
func end_run(cause: StringName = &"") -> void:
	if phase != Phase.PLAYING:
		return
	state.end_cause = cause if cause != &"" else config.default_end_cause
	phase = Phase.DYING
	SignalBus.run_ended.emit(state.end_cause)


func _on_run_ended(_cause: StringName) -> void:
	if config.restart_delay > 0.0:
		await get_tree().create_timer(config.restart_delay).timeout
	if phase == Phase.DYING:
		start_run()
