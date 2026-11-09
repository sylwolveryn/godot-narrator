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
## How many times each narration line was heard (task-087), beat id -> count. A line in heard_beats without a count
## (older saves) counts as heard once.
@export var beat_counts: Dictionary = {}
## True once the multi-glyph entity has been unlocked (death_count reached EntityGrowthConfig.growth_unlock_deaths). Never reverts.
@export var entity_unlocked: bool = false
## The active form after the unlock: EntityForm.SINGLE or EntityForm.GROWN (task-018 lets the player switch).
@export var entity_form: String = "single"
## True once the grow moment has played, so it plays exactly once even if the game is closed in between.
@export var entity_grow_played: bool = false
## True once the in-world menu has been unlocked (death_count reached MenuConfig.menu_unlock_deaths, task-018). Never reverts.
@export var menu_unlocked: bool = false
## Origin rule-out ledger state (task-039). Written ONLY by OriginLedger.
## Natures ruled out, oldest strike first.
@export var struck_natures: PackedStringArray = PackedStringArray()
## Natures whose trial is armed (their claim beat was heard and they are alive).
@export var armed_trials: PackedStringArray = PackedStringArray()
## Nature id -> number of times it was struck (scales the retry threshold, drives the ledger crack).
@export var strike_counts: Dictionary = {}
## Persistent run number (run_count) of the last strike; 0 = never. Enforces the per-run strike cap.
@export var last_strike_run: int = 0
## Language understanding (task-065). Written ONLY by LanguageProgress.
## Language id (String) -> understanding in percent (float, 0..LanguageConfig.max_percent).
@export var language_understanding: Dictionary = {}
## The selected (narration) language id. Empty = not set yet (a new save; LanguageProgress fills the defaults).
@export var selected_language: String = ""
## Language ids available in the Language menu, in unlock order.
@export var unlocked_languages: PackedStringArray = PackedStringArray()
## Cell types (MapLegend names) ever discovered; the first discovery of a type gives understanding once.
@export var discovered_types: PackedStringArray = PackedStringArray()
## Cells walked since the last step gain (0..LanguageConfig.tiles_per_percent - 1).
@export var language_step_remainder: int = 0
## Dirt walls (task-070). Written ONLY by DirtWalls. Dirt cells eaten ever, on every map.
@export var walls_eaten: int = 0
## walls_eaten value at which WALLS_DEVOURED fires next (0 = not rolled yet).
@export var next_devour_at: int = 0
## Enemy remains (task-076). Written ONLY by EnemyRemains. Diamonds picked up ever, on every map.
@export var diamonds: int = 0
## Consumption (task-077). Written ONLY by SaveService (from SignalBus.consumed). Consumable kind (String) -> count ever.
@export var consumed: Dictionary = {}
## Menu item ids the player has seen in an open menu (task-077); written ONLY by SaveService for MenuController.
@export var seen_menu_items: PackedStringArray = PackedStringArray()
## True once seen_menu_items was first filled (items already offered before tracking began count as seen).
@export var menu_seen_initialized: bool = false
## Crafting (task-088). Written ONLY by SaveService for Crafting. Consumable kind -> amount spent (stock = consumed -
## spent), recipe ids learned through research (in learning order), recipe id -> times crafted.
@export var spent: Dictionary = {}
@export var known_crafts: PackedStringArray = PackedStringArray()
@export var crafted: Dictionary = {}
