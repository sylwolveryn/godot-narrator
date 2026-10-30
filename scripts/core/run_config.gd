class_name RunConfig
extends Resource
## Tunable values for the run lifecycle.

## Seconds between a run ending and the next run starting. Death never pauses the game.
@export_range(0.0, 30.0, 0.1) var restart_delay: float = 1.5
## Cause recorded when a run ends without a specific reason.
@export var default_end_cause: StringName = &"unknown"
## When true, a restart replays the (shortened) intro before the next run; otherwise it restarts at once.
@export var intro_on_restart: bool = false
