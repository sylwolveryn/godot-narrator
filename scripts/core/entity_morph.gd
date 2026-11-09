class_name EntityMorph
extends RefCounted
## The slow shape change of the many form (task-099): the body is a fixed set of glyph slots that glide between
## silhouettes - the base (human) formation and the morph shapes (lion head, angelic wings, hand; EntityGrowthConfig).
## Purely visual: the collider always follows the base formation (EntityGrowthConfig.body_extents_for).
##
## Slots: every shape lists its glyph cells in reading order (top to bottom, left to right); slot i takes the cell
## floor(i * M / N) of a shape with M cells (N = slot count = the largest shape). Slots that share a cell are hidden in
## that shape, so they fade in or out while the body morphs. A filler cell ('*') shows the slot's own body glyph (picked
## from the body palette, seeded by the identity), a pattern character shows itself.
##
## Timing: hold the base, morph to another shape over a random morph duration, hold it, morph back to the base, hold,
## then the next shape (never the one just shown). `step` advances it; `progress` is the eased 0..1 of the running morph.
## Pure data, no nodes; EntityGlyphView writes it into its instance buffer.

## One shape resolved for the slots: offsets from the heart (world units, x right, y up), glyphs, visibility, structure.
class Shape:
	var id: StringName = &""
	var offsets: PackedVector2Array = PackedVector2Array()
	var glyphs: PackedStringArray = PackedStringArray()
	var visible: PackedByteArray = PackedByteArray()
	var structural: PackedByteArray = PackedByteArray()
	var rings: PackedInt32Array = PackedInt32Array()

enum Phase { HOLD, MORPH }

## Index 0 = the base shape, then the morph shapes.
var shapes: Array[Shape] = []
## Shape the body shows (or morphs from), and the shape it morphs to (== from while holding).
var from_index: int = 0
var to_index: int = 0
var phase: Phase = Phase.HOLD
## Seconds into the current phase, and its length.
var time: float = 0.0
var length: float = 0.0

var _config: EntityGrowthConfig
var _rng := RandomNumberGenerator.new()
var _last_other: int = -1


## Builds the slots of `identity` from the config's base formation and morph shapes. Empty without a base formation.
static func build(config: EntityGrowthConfig, identity: String) -> EntityMorph:
	var m := EntityMorph.new()
	m._config = config
	m._rng.seed = hash("%s/morph" % identity)
	var base: EntityFormation = config.formation_for(identity)
	if base == null:
		return m
	var formations: Array[EntityFormation] = [base]
	if config.morph_enabled:
		for f in config.morph_shapes:
			if f != null and f.glyph_count() > 0:
				formations.append(f)
	var cells: Array = []
	var count: int = 0
	for f in formations:
		var c: Array = _cells(f)
		cells.append(c)
		count = maxi(count, c.size())
	var fill_rng := RandomNumberGenerator.new()
	fill_rng.seed = hash("%s/%s" % [identity, base.id])
	var fillers := PackedStringArray()
	for i in count:
		var palette: String = config.body_glyphs
		fillers.append(palette[fill_rng.randi() % palette.length()] if palette != "" else "o")
	for k in formations.size():
		m.shapes.append(_resolve(formations[k], cells[k], count, fillers))
	m.reset()
	return m


## Back to holding the base shape (a new grow, a new identity).
func reset() -> void:
	from_index = 0
	to_index = 0
	phase = Phase.HOLD
	time = 0.0
	length = _hold_length()


## Number of glyph slots (the same in every shape).
func slot_count() -> int:
	return shapes[0].offsets.size() if not shapes.is_empty() else 0


## True when there is anything to morph to.
func can_morph() -> bool:
	return shapes.size() > 1


## Advances the clock. Returns true when the shapes the body morphs between changed (a morph started or ended), i.e.
## when the instance buffer has to be rewritten.
func step(delta: float) -> bool:
	if not can_morph():
		return false
	time += delta
	if time < length:
		return false
	time = 0.0
	if phase == Phase.HOLD:
		phase = Phase.MORPH
		to_index = _next_shape()
		length = _rng.randf_range(_config.morph_duration_min, _config.morph_duration_max)
	else:
		phase = Phase.HOLD
		from_index = to_index
		length = _hold_length()
	return true


## Eased 0..1 of the running morph (0 while holding).
func progress() -> float:
	if phase != Phase.MORPH or length <= 0.0:
		return 0.0
	return smoothstep(0.0, 1.0, clampf(time / length, 0.0, 1.0))


func _hold_length() -> float:
	if _config == null:
		return 0.0
	return _rng.randf_range(_config.morph_hold_min, _config.morph_hold_max)


## From the base: another shape (not the last one shown, when there is a choice); from any other shape: the base.
func _next_shape() -> int:
	if from_index != 0:
		return 0
	var choices: Array[int] = []
	for i in range(1, shapes.size()):
		if i != _last_other or shapes.size() == 2:
			choices.append(i)
	var pick: int = choices[_rng.randi() % choices.size()]
	_last_other = pick
	return pick


## Glyph cells of a formation in reading order: [Vector2i cell, character].
static func _cells(f: EntityFormation) -> Array:
	var out: Array = []
	for y in f.rows.size():
		var row: String = f.rows[y]
		for x in row.length():
			var ch: String = row[x]
			if ch != EntityFormation.EMPTY and ch != " " and ch != EntityFormation.HEART:
				out.append([Vector2i(x, y), ch])
	return out


static func _resolve(f: EntityFormation, cells: Array, count: int, fillers: PackedStringArray) -> Shape:
	var s := Shape.new()
	s.id = f.id
	var heart: Vector2i = Vector2i.ZERO
	for y in f.rows.size():
		var x: int = f.rows[y].find(EntityFormation.HEART)
		if x >= 0:
			heart = Vector2i(x, y)
	var m: int = cells.size()
	var last: int = -1
	for i in count:
		var k: int = (i * m) / count if m > 0 else -1
		if k < 0:
			s.offsets.append(Vector2.ZERO)
			s.glyphs.append(fillers[i])
			s.visible.append(0)
			s.structural.append(0)
			s.rings.append(0)
			continue
		var cell: Vector2i = cells[k][0]
		var ch: String = cells[k][1]
		var filler: bool = ch == EntityFormation.FILLER
		s.offsets.append(Vector2(float(cell.x - heart.x) * f.advance.x, float(heart.y - cell.y) * f.advance.y))
		s.glyphs.append(fillers[i] if filler else ch)
		s.visible.append(1 if k != last else 0)
		s.structural.append(0 if filler else 1)
		s.rings.append(maxi(absi(cell.x - heart.x), absi(cell.y - heart.y)))
		last = k
	return s
