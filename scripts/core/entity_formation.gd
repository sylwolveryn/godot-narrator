class_name EntityFormation
extends Resource
## One silhouette of the grown entity (task-017) as a small text pattern. The identity glyph is the heart of every
## formation and is drawn by the player glyph itself: '@' marks its cell. '.' is empty, '*' is a filler glyph picked
## from the body palette (seeded by the identity, so the same identity always grows the same body), any other
## character is drawn as itself. Rows run top to bottom. Instances: resources/config/formations/*.tres.

@export var id: StringName = &"formation"
## Pattern rows, top to bottom, all the same width, exactly one '@'.
@export var rows: PackedStringArray = PackedStringArray()
## World units between neighbouring pattern cells (x across, y down).
@export var advance: Vector2 = Vector2(0.95, 0.95)

const HEART: String = "@"
const EMPTY: String = "."
const FILLER: String = "*"


## Resolves the pattern for an identity: offsets from the heart, glyphs, structure flags. Deterministic per identity.
func resolve(identity: String, palette: String) -> EntityLayout:
	var layout := EntityLayout.new()
	var heart: Vector2i = _heart_cell()
	if heart.x < 0:
		return layout
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%s" % [identity, id])
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch: String = row[x]
			if ch == EMPTY or ch == " " or ch == HEART:
				continue
			var glyph: String = ch
			var structural: int = 1
			if ch == FILLER:
				structural = 0
				glyph = palette[rng.randi() % palette.length()] if palette != "" else "o"
			layout.offsets.append(Vector2(float(x - heart.x) * advance.x, float(heart.y - y) * advance.y))
			layout.glyphs.append(glyph)
			layout.structural.append(structural)
			layout.rings.append(maxi(absi(x - heart.x), absi(y - heart.y)))
	return layout


## Number of glyphs the pattern adds around the heart.
func glyph_count() -> int:
	var n: int = 0
	for row in rows:
		for i in row.length():
			var ch: String = row[i]
			if ch != EMPTY and ch != " " and ch != HEART:
				n += 1
	return n


func _heart_cell() -> Vector2i:
	for y in rows.size():
		var x: int = rows[y].find(HEART)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)
