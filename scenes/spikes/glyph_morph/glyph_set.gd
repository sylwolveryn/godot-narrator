extends RefCounted
## Spike B: the glyph set baked into glyph_atlas.png. Index = position in CHARS.
## Shared by tools/build_spike_glyph_atlas.gd (bakes it) and the runtime (looks glyphs up).

const CHARS: String = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~░▒▓█■●○◆▲·•─│┌┐└┘"
const COLUMNS: int = 16
const CELL_PX: int = 64


static func index_of(ch: String) -> int:
	var i: int = CHARS.find(ch)
	return i if i >= 0 else CHARS.find("?")


static func rows() -> int:
	return (CHARS.length() + COLUMNS - 1) / COLUMNS
