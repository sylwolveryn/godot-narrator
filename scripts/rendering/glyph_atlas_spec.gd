class_name GlyphAtlasSpec
extends RefCounted
## Layout of resources/glyphs/glyph_atlas.png, the glyph atlas of the glyph-surface material.
## One row per surface (SURFACES); column 0 of a row is blank, columns 1..COLUMNS-1 are the density ramp from sparse to
## dense. The glyphs come from the DB table glyph_ramp: GlyphAnimView rasterises them at runtime (GlyphRampAtlas) and
## tools/build_glyph_atlas.gd bakes the same rows from data/db/seed.json into the fallback PNG. The shader
## (glyph_surface.gdshader) hardcodes COLUMNS and ROWS.

const COLUMNS: int = 8
const ROWS: int = 6
const CELL_PX: int = 32
const FONT_PX: int = 28
## Share of the font size the baseline sits below the cell centre.
const BASELINE_DROP: float = 0.34
## Atlas row of the dirt glyphs (glyph_surface.gdshader DIRT_ROW).
const DIRT_ROW: int = 5
const ATLAS_PATH: String = "res://resources/glyphs/glyph_atlas.png"
## Surface of each atlas row (GlyphSurfaceType order, then the dirt row). The glyphs of a row come from the DB table
## glyph_ramp (task-079, GlyphRampAtlas); the baked PNG is only the fallback until the DB / seed rows are drawn.
const SURFACES: PackedStringArray = ["wall", "floor", "spikes", "corruption", "item", "dirt"]
