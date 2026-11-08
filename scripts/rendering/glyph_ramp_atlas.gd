class_name GlyphRampAtlas
extends RefCounted
## Base glyph ramps (task-079) as an atlas image for the glyph-surface material: one row per surface (GlyphAtlasSpec
## layout), column 0 blank, columns 1..COLUMNS-1 the ramp from sparse to dense. The ramps come from the DB table
## `glyph_ramp` (surface, chars); nothing is hard-coded here. Ramp text is split into grapheme clusters (decision-003:
## an emoji with a variation selector, a ZWJ sequence or a letter with a combining mark is one glyph) and spread over
## the density columns, so any number of glyphs works. Clusters are drawn with Font.draw_string (HarfBuzz shaping, font
## fallback) and shrunk to fit their cell.

const TABLE: String = "glyph_ramp"
## Fonts the ramp glyphs are drawn with (first available; the system font fallback covers the rest).
const FONT_NAMES: PackedStringArray = ["Consolas", "Courier New", "monospace"]
## Share of the cell a glyph may be wide before it is shrunk.
const FIT: float = 0.95


## Draws the rows it is given (row index -> ramp text) white on black.
class Painter extends Node2D:
	var font: Font
	var rows: Dictionary = {}

	func _draw() -> void:
		var cell: float = float(GlyphAtlasSpec.CELL_PX)
		draw_rect(Rect2(Vector2.ZERO, Vector2(GlyphAtlasSpec.COLUMNS, GlyphAtlasSpec.ROWS) * cell), Color.BLACK)
		for row: int in rows:
			var glyphs: PackedStringArray = GlyphRampAtlas.columns_for(GlyphRampAtlas.graphemes(rows[row]), GlyphAtlasSpec.COLUMNS - 1)
			for i in glyphs.size():
				GlyphRampAtlas.draw_cluster(self, font, glyphs[i], Vector2((i + 1) * cell, row * cell), cell)


## The grapheme clusters of a text (what a player sees as single characters), spaces included.
static func graphemes(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	if text.is_empty():
		return out
	var breaks: PackedInt32Array = TextServerManager.get_primary_interface().string_get_character_breaks(text)
	var start: int = 0
	for end in breaks:
		out.append(text.substr(start, end - start))
		start = end
	if start < text.length():
		out.append(text.substr(start))
	return out


## `count` glyphs spread evenly over `clusters` (fewer clusters repeat, more are sampled), sparse to dense.
static func columns_for(clusters: PackedStringArray, count: int) -> PackedStringArray:
	var out := PackedStringArray()
	if clusters.is_empty() or count <= 0:
		return out
	for k in count:
		out.append(clusters[mini(clusters.size() - 1, k * clusters.size() / count)])
	return out


## Ramp text per atlas row from the DB rows (only surfaces with a non-empty ramp).
static func rows_from_table(rows: Array) -> Dictionary:
	var out: Dictionary = {}
	for row: Variant in rows:
		if not row is Dictionary:
			continue
		var index: int = GlyphAtlasSpec.SURFACES.find(str((row as Dictionary).get("surface", "")))
		var chars: String = str((row as Dictionary).get("chars", ""))
		if index >= 0 and not chars.strip_edges().is_empty():
			out[index] = chars
	return out


## One cluster centred in the cell at `origin`, white, shrunk when wider than the cell.
static func draw_cluster(canvas: CanvasItem, font: Font, cluster: String, origin: Vector2, cell: float) -> void:
	if cluster.strip_edges().is_empty():
		return
	var size: int = GlyphAtlasSpec.FONT_PX
	var width: float = font.get_string_size(cluster, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if width > cell * FIT:
		size = maxi(1, int(size * cell * FIT / width))
		width = font.get_string_size(cluster, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := origin + Vector2((cell - width) * 0.5, cell * 0.5 + size * GlyphAtlasSpec.BASELINE_DROP)
	canvas.draw_string(font, pos, cluster, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


static func make_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = FONT_NAMES
	return font
