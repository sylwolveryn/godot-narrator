class_name GlyphAtlasSpec
extends RefCounted
## Layout of resources/glyphs/glyph_atlas.png, the glyph atlas of the glyph-surface material.
## One row per surface type (GlyphSurfaceType ids) plus a special row; column 0 of a type row is
## blank, columns 1..COLUMNS-1 are the density ramp from sparse to dense. Baked by
## tools/build_glyph_atlas.gd; the shader (glyph_surface.gdshader) hardcodes COLUMNS and ROWS.

const COLUMNS: int = 8
const ROWS: int = 6
const CELL_PX: int = 32
const FONT_PX: int = 28
## Share of the font size the baseline sits below the cell centre.
const BASELINE_DROP: float = 0.34
const ATLAS_PATH: String = "res://resources/glyphs/glyph_atlas.png"
## Row strings, COLUMNS chars each (space = blank). Rows 0-4 follow GlyphSurfaceType; row 5 is special.
const ROW_GLYPHS: Array[String] = [
	" .:+xX#M",   # wall
	" .,:;+o0",   # floor
	" '^!AVW#",   # spikes
	" `~?%&$#",   # corruption
	" 1l0I|8B",   # item
	"@*o+xO^&",   # special
]
