class_name PersistentProgress
extends Resource
## Data that outlives a run (and, once task-013 lands, a launch). Owned by SaveService.
## Not per-run state: per-run values live in RunState.

## The character's ASCII identity, chosen randomly once and then reused forever. Empty = not chosen yet.
@export var identity_glyph: String = ""
## Number of runs started across all launches.
@export var run_count: int = 0
## Map memory: map id (StringName) -> PackedVector2Array of revealed cell coordinates (x, y as floats).
@export var revealed_cells: Dictionary = {}
