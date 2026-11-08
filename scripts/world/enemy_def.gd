class_name EnemyDef
extends Resource
## One enemy type (task-075): how it moves, whether it kills, what it leaves behind (task-076) and how it looks.
## The gameplay numbers can be overridden per kind by the DB table `enemy_def` (EnemyConfig.from_tables).

enum Movement { CRAWLER, HUNTER, WANDERER }

## DB key (enemy_def.kind) and the name used in run end causes (`enemy_<kind>`).
@export var kind: StringName = &"crawler"
@export var movement: Movement = Movement.CRAWLER

@export_group("Movement")
## Cells per second.
@export var speed: float = 2.0
## Touching the player ends the run.
@export var lethal: bool = true
## Hunter: seconds between path searches, and the search window (cells, Chebyshev) around the hunter. A player outside
## it is not hunted (the hunter wanders instead).
@export var repath_seconds: float = 0.6
@export var search_radius: int = 16
## Wanderer (and an idle hunter): chance to re-roll the direction at a junction, and the straight run length (cells)
## after which it re-rolls anyway.
@export_range(0.0, 1.0) var turn_chance: float = 0.35
@export var run_min: int = 3
@export var run_max: int = 9

@export_group("Remains")
## Diamonds it bursts into when destroyed (task-076).
@export var diamonds: int = 0
## Leaves a black hole on its cell when destroyed (task-076).
@export var black_hole: bool = false

@export_group("Look")
## Body glyph first, then the satellite glyphs (legs, eyes, tail) drawn around it.
@export var glyphs: String = "Ж/\\"
@export var color: Color = Color(1.0, 0.65, 0.2)
## Colour of the satellite glyphs.
@export var accent: Color = Color(1.0, 0.85, 0.5)
## Body glyph half-size (world units) and satellite size relative to it.
@export var body_size: float = 0.32
@export var satellite_scale: float = 0.55
## Satellite distance from the body (world units), the angle of the first one (degrees, 0 = screen right, around
## the body in the billboard plane) and the spread between them; orbit speed (degrees per second, 0 = fixed legs).
@export var satellite_radius: float = 0.3
@export var satellite_start_degrees: float = 0.0
@export var satellite_step_degrees: float = 180.0
@export var orbit_degrees_per_second: float = 0.0
## Idle animation: body bob (world units) and its speed (Hz); satellite wiggle (world units) and its speed (Hz).
@export var bob_amount: float = 0.05
@export var bob_hz: float = 1.6
@export var wiggle_amount: float = 0.06
@export var wiggle_hz: float = 6.0
## Height of the body centre above the floor (world units).
@export var hover: float = 0.45
## Glow of the glyphs (0..1, the ball shader's rim/halo).
@export var glow: float = 0.35


## Run end cause of a death by this kind.
func end_cause() -> StringName:
	return StringName("enemy_" + String(kind))


## A copy with the DB columns of `row` applied (missing columns keep this def's values).
func with_row(row: Dictionary) -> EnemyDef:
	var out: EnemyDef = duplicate() as EnemyDef
	for key: String in ["speed", "repath_seconds", "turn_chance"]:
		if row.has(key):
			out.set(key, float(row[key]))
	for key: String in ["search_radius", "run_min", "run_max", "diamonds"]:
		if row.has(key):
			out.set(key, int(row[key]))
	for key: String in ["lethal", "black_hole"]:
		if row.has(key):
			out.set(key, bool(row[key]))
	return out
