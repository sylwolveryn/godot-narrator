extends Node2D
## Spike B: draws every glyph of glyph_set.gd centred in its atlas cell (white on transparent).
## Used only by tools/build_spike_glyph_atlas.gd inside a SubViewport.

const GlyphSet := preload("res://scenes/spikes/glyph_morph/glyph_set.gd")
const FONT_PX: int = 50
const BASELINE_DROP: float = 0.34

var font: Font


func _draw() -> void:
	var cell: float = float(GlyphSet.CELL_PX)
	for i in GlyphSet.CHARS.length():
		var ch: String = GlyphSet.CHARS[i]
		if ch == " ":
			continue
		var col: int = i % GlyphSet.COLUMNS
		var row: int = i / GlyphSet.COLUMNS
		var adv: float = font.get_char_size(ch.unicode_at(0), FONT_PX).x
		var x: float = col * cell + (cell - adv) * 0.5
		var y: float = row * cell + cell * 0.5 + FONT_PX * BASELINE_DROP
		font.draw_char(get_canvas_item(), Vector2(x, y), ch.unicode_at(0), FONT_PX, Color.WHITE)
