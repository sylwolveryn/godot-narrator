class_name EntityLayout
extends RefCounted
## The resolved glyphs of one entity: where each body glyph sits relative to the heart (the identity glyph), which
## glyph it shows, whether it is a structural (pattern) glyph or a filler, and its distance from the heart in cells.
## Built by EntityFormation.resolve(); read by EntityGlyphView.

## Offsets from the heart in world units on the screen plane (x right, y up).
var offsets: PackedVector2Array = PackedVector2Array()
## The glyph of each slot.
var glyphs: PackedStringArray = PackedStringArray()
## 1 for a glyph written in the pattern, 0 for a filler picked from the body palette.
var structural: PackedByteArray = PackedByteArray()
## Distance from the heart in pattern cells (Chebyshev); drives the growth stagger.
var rings: PackedInt32Array = PackedInt32Array()


func size() -> int:
	return glyphs.size()
