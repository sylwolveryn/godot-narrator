class_name AsciiConfig
extends Resource
## Tunables for the ASCII post-process. Instance: resources/config/ascii_config.tres.

## Master switch. When false the 3D render is shown unmodified (debugging).
@export var enabled: bool = true
## Size of one glyph cell in screen pixels.
@export var cell_size: Vector2i = Vector2i(10, 18)
## Glyphs ordered from darkest to brightest. The first one is usually a space.
@export var glyph_ramp: String = " .:-=+*#%@"
## Preferred monospace system fonts, first available wins.
@export var font_names: PackedStringArray = PackedStringArray(["Consolas", "Courier New", "monospace"])
## Font size used to rasterise the glyph atlas, in pixels.
@export var font_size: int = 16
## Glyph colour.
@export var foreground_color: Color = Color(0.85, 0.95, 0.85)
## Cell background colour.
@export var background_color: Color = Color(0.02, 0.03, 0.02)
## 0 = glyphs use foreground_color, 1 = glyphs use the scene colour of the cell.
@export_range(0.0, 1.0) var scene_color_mix: float = 0.0
## Multiplier applied to the sampled luminance before choosing a glyph.
@export var brightness_gain: float = 1.6
