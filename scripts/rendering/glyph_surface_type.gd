class_name GlyphSurfaceType
extends RefCounted
## Surface type ids of the glyph-surface material (shaders/glyph_surface.gdshader). The id is
## stored in vertex COLOR.r (id / TYPE_DIV) and doubles as the row of the glyph atlas.

const WALL: int = 0
const FLOOR: int = 1
const SPIKES: int = 2
const CORRUPT: int = 3
const ITEM: int = 4
## Number of surface types the shader has palette entries for.
const COUNT: int = 5
## Vertex colour divisor (the shader multiplies COLOR.r by the same value).
const TYPE_DIV: float = 8.0
