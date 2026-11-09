class_name EntityGrowthConfig
extends Resource
## Tuning for the multi-glyph entity (task-017): when it unlocks, what it looks like, and how it grows.
## Instance: resources/config/entity_growth_config.tres (formations in resources/config/formations/).

@export_group("Unlock")
## The entity unlocks when PersistentProgress.death_count reaches this (every M1 run ends in a death, so this is "after run N").
@export var growth_unlock_deaths: int = 3

@export_group("Body")
## Silhouettes; the identity picks one (hash of the identity glyph), so one identity always grows one body.
@export var formations: Array[EntityFormation] = []
## Glyphs that fill the '*' cells of a formation.
@export var body_glyphs: String = "o+=:%&x"
## Height of one body glyph tile in world units (the heart is glyph_size in GlyphFxConfig).
@export var glyph_size: float = 0.9
## Fraction of a body quad the glyph tile covers (the rest holds the dark backing outline).
@export_range(0.2, 1.0) var glyph_fill: float = 0.8
## Colour of filler glyphs, and of structural glyphs; brightness varies per glyph by up to body_variation.
@export var filler_color: Color = Color(1.0, 0.86, 0.55)
@export var structural_color: Color = Color(1.0, 0.98, 0.9)
@export_range(0.0, 0.8) var body_variation: float = 0.2
## Dark backing around body glyphs (fraction of the glyph tile) and its colour: keeps them readable on the lit floor.
@export_range(0.0, 0.2) var outline_width: float = 0.07
@export var outline_color: Color = Color(0.01, 0.005, 0.03, 1.0)
## Font weight of body glyphs (400 normal, 700 bold); heavier strokes read better at small sizes.
@export_range(100, 900) var font_weight: int = 700

@export_group("Grow moment")
## Seconds after the run starts before the entity begins to grow (the single glyph is seen first).
@export var grow_delay: float = 0.8
## Seconds one glyph flies for.
@export var grow_duration: float = 0.85
## Seconds of stagger per pattern ring away from the heart, plus a random extra up to grow_jitter.
@export var grow_stagger: float = 0.12
@export var grow_jitter: float = 0.18
## Glyphs gather from this far away (world units) around the heart.
@export var gather_radius: float = 4.5
## Height of the arc a flying glyph makes (world units).
@export var arc_height: float = 1.1
## Spin: each glyph turns a whole number of times (1 up to about this many) in flight, random direction, so it lands upright.
@export var spin_turns: float = 1.5
## Scale pop in mid-flight (fraction) and glyph size at the start (fraction of its final size).
@export var pop: float = 0.45
@export var start_size_ratio: float = 0.35
## Brightness flash while flying (added to the colour, fades on landing). Keep it soft: no strobing.
@export var flash: float = 0.18
## Overshoot of the landing ease (0 = none). 1.35 is a gentle bounce.
@export var overshoot: float = 1.35
## Colour the glyphs start with (cool, like the floor they are gathered from).
@export var gather_color: Color = Color(0.45, 0.62, 0.78)
## Glyphs they flip from in flight (one is picked per glyph).
@export var gather_glyphs: String = ".,:;"
## The heart swells by this fraction when the glyphs arrive, over heart_pulse_time seconds.
@export var heart_pulse: float = 0.22
@export var heart_pulse_time: float = 0.5
## Seconds the entity takes to fold back into the single glyph (switching form).
@export var fold_duration: float = 0.6

@export_group("Life")
## Slow bob of settled glyphs (world units, radians per second).
@export var bob_amount: float = 0.035
@export var bob_speed: float = 2.3
## Outer glyphs lag behind when the entity moves: displacement per unit of speed, and how fast the lag follows.
@export var trail_lag: float = 0.05
@export var trail_follow: float = 8.0

@export_group("Erosion and death")
## Eroding body glyphs stay more solid than the heart so the silhouette survives: share of the substitute glyph blended in
## at erosion 1, how strongly the hazard tint replaces the colour, and the opacity at erosion 1.
@export_range(0.0, 1.0) var erosion_blend_max: float = 0.5
@export_range(0.0, 1.0) var erosion_tint_strength: float = 0.55
@export_range(0.0, 1.0) var erosion_min_alpha: float = 0.85
## Eroding: this share of the glyphs drift off and fade in turn at erosion 1.
@export_range(0.0, 1.0) var shed_share: float = 0.35
## Seconds of one drift-off cycle, and how far a glyph drifts (world units).
@export var shed_period: float = 3.4
@export var shed_distance: float = 0.9
## Opacity left of a drifting glyph at its most faded.
@export_range(0.0, 1.0) var shed_min_alpha: float = 0.35
## Seconds the substitute glyph of an eroding body glyph lasts (crossfaded).
@export var sub_period: float = 2.4
## How far the glyphs fly when the entity bursts at death (world units).
@export var death_spread: float = 2.6


## The formation this identity grows into.
## Task-090: the grown body collides as a whole and must fit where it is taken (radius: body_radius_for). Off = the
## heart-sized collider of the single glyph in every form (no fit check).
@export var whole_body: bool = true

@export_group("Brain")
## Task-091: the brain form unlocks once this many maps were discovered completely and this many teleport trips made.
@export var brain_maps_needed: int = 1
@export var brain_teleports_needed: int = 2


## Ground radius of the grown body (task-090): half the width of the identity's formation (its widest glyph from the
## heart, plus half a glyph). The many form collides with and must fit in a lying capsule this wide and
## body_extents_for(identity).y deep (task-094).
func body_radius_for(identity: String) -> float:
	return body_extents_for(identity).x


## Ground half-size of the grown body (task-094): x = half the formation's width (across the screen), y = half its
## depth (up the screen), each its farthest glyph from the heart plus half a glyph. Zero without a formation.
func body_extents_for(identity: String) -> Vector2:
	var f: EntityFormation = formation_for(identity)
	if f == null:
		return Vector2.ZERO
	var heart := Vector2i(-1, -1)
	for y in f.rows.size():
		if f.rows[y].find(EntityFormation.HEART) >= 0:
			heart = Vector2i(f.rows[y].find(EntityFormation.HEART), y)
	var far := Vector2i.ZERO
	for y in f.rows.size():
		var row: String = f.rows[y]
		for c in row.length():
			if row[c] != EntityFormation.EMPTY and row[c] != " ":
				far = Vector2i(maxi(far.x, absi(c - heart.x)), maxi(far.y, absi(y - heart.y)))
	return Vector2(far.x * f.advance.x, far.y * f.advance.y) + Vector2.ONE * glyph_size * 0.5


func formation_for(identity: String) -> EntityFormation:
	if formations.is_empty():
		return null
	return formations[absi(hash(identity)) % formations.size()]


## Upper bound in seconds from the start of a grow until the last glyph has landed.
func grow_total() -> float:
	var widest: float = 0.0
	for f in formations:
		for row in f.rows:
			widest = maxf(widest, float(row.length()))
	return widest * 0.5 * grow_stagger + grow_jitter + grow_duration
