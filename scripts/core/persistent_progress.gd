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
## Number of runs that ended in death across all launches.
@export var death_count: int = 0
## Ids of narration beats already heard (filled by the narrator, task-014).
@export var heard_beats: PackedStringArray = PackedStringArray()
## True once the multi-glyph entity has been unlocked (death_count reached EntityGrowthConfig.growth_unlock_deaths). Never reverts.
@export var entity_unlocked: bool = false
## The active form after the unlock: EntityForm.SINGLE or EntityForm.GROWN (task-018 lets the player switch).
@export var entity_form: String = "single"
## True once the grow moment has played, so it plays exactly once even if the game is closed in between.
@export var entity_grow_played: bool = false
