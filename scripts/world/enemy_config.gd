class_name EnemyConfig
extends Resource
## Enemies (task-075): the types, the map spawn types and the shared numbers. Instance:
## resources/config/enemy_config.tres (tools/build_resources.gd). Per-kind gameplay values are overridden by the DB
## table `enemy_def` (key `kind`; from_tables), the bundled seed when the server is offline.

const TABLE: String = "enemy_def"
const KEY: String = "kind"
## Crawler handedness: which wall it keeps.
const HAND_LEFT: int = -1
const HAND_RIGHT: int = 1

## The enemy types (EnemyDef.kind is the key).
@export var defs: Array[EnemyDef] = []
## Map spawn type (MapLegend.enemy_spawns values) -> enemy kind.
@export var spawn_kinds: Dictionary[StringName, StringName] = {
	&"crawler_left": &"crawler",
	&"crawler_right": &"crawler",
	&"hunter": &"hunter",
	&"wanderer": &"wanderer",
}
## Map spawn type -> crawler hand (HAND_LEFT / HAND_RIGHT); others need none.
@export var spawn_hands: Dictionary[StringName, int] = {
	&"crawler_left": HAND_LEFT,
	&"crawler_right": HAND_RIGHT,
}

@export_group("Contact")
## An enemy closer than this to the player body centre (world units, plus the body radius) touches it.
@export var contact_radius: float = 0.3
## Seconds an enemy waits for a cell another enemy holds before it picks another way (no deadlock in corridors).
@export var block_wait_seconds: float = 1.2
## Hunter path searches allowed per physics step over all hunters (the others keep their old path or wander this step;
## repath timers start staggered), so many hunters never search in the same frame.
@export var max_searches_per_step: int = 2

@export_group("Look")
## Fonts of the glyph atlas (all enemy glyphs are rasterised once at start).
@export var glyph_font_names: PackedStringArray = PackedStringArray(["Consolas", "Cascadia Mono", "Segoe UI Symbol", "monospace"])
@export var glyph_tile_px: int = 48
@export var glyph_font_px: int = 40
## Seconds a newly seen / newly hidden enemy takes to fade in / out.
@export var reveal_fade: float = 0.25
## Destruction burst: fragments (the creature's glyphs) flying out, their count, life (seconds), speed (world units
## per second) and upward kick.
@export var puff_count: int = 8
@export var puff_seconds: float = 0.55
@export var puff_speed: float = 2.4
@export var puff_lift: float = 1.6
## Glyph quads in the pool (all enemy glyphs plus the bursts).
@export var max_glyphs: int = 1024
@export var rim_color: Color = Color(1.0, 0.95, 0.85)


## The def of a kind (null when unknown).
func def_for(kind: StringName) -> EnemyDef:
	for d in defs:
		if d != null and d.kind == kind:
			return d
	return null


## The def of a map spawn type (null when unknown).
func def_for_spawn(spawn: StringName) -> EnemyDef:
	return def_for(spawn_kinds.get(spawn, &""))


## Crawler hand of a map spawn type (HAND_LEFT when it has none).
func hand_for_spawn(spawn: StringName) -> int:
	return spawn_hands.get(spawn, HAND_LEFT)


## A copy whose defs carry the `enemy_def` rows of `tables` (kinds without a row keep their defaults).
func from_tables(tables: Dictionary) -> EnemyConfig:
	var out: EnemyConfig = duplicate() as EnemyConfig
	var defs_out: Array[EnemyDef] = []
	for d in defs:
		if d == null:
			continue
		var row: Dictionary = {}
		for r: Variant in tables.get(TABLE, []):
			if r is Dictionary and str((r as Dictionary).get(KEY, "")) == String(d.kind):
				row = r
				break
		defs_out.append(d.with_row(row))
	out.defs = defs_out
	return out
