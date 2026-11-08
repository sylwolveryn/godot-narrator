class_name LargeObjectDef
extends Resource
## A multi-cell map prop (task-058). Repeating `character` in the map makes ONE object per rectangle of adjacent cells
## (LargeObjectMerger): `GG` is one object two cells wide, `GG\nGG` one object 2x2. The cells under it hold `type` in
## MapData.types and are drawn as floor; MapLoader adds the collision, LargeObjectView draws the ASCII art scaled to
## the footprint. Adding a new def to MapLegend.large_objects is all a new prop needs.
## Instances: resources/config/large_objects/*.tres (built by tools/build_resources.gd).

## Cell type stored in MapData for the cells of this object (also the key in MapLegend.large_objects).
@export var type: StringName = &""
## Map-file character of the object.
@export var character: String = ""

@export_group("Art")
## The ASCII art, top line first. Drawn with a monospace font, centred, standing on the floor.
@export var art_lines: PackedStringArray = PackedStringArray()
## Optional layer mask, same shape as `art_lines`: the character at a position names the layer of that art glyph.
## Missing lines / positions and spaces belong to the base layer " ". Each layer is one Label3D with its own colour.
@export var mask_lines: PackedStringArray = PackedStringArray()
## Layer char -> colour of its glyphs. The base layer is " ". A layer without a colour uses `base_color`.
@export var layer_colors: Dictionary[String, Color] = {}
@export var base_color: Color = Color(0.6, 0.62, 0.75)
## Outline of the glyphs (a dark rim keeps the art readable over the floor glyphs).
@export var outline_color: Color = Color(0.02, 0.02, 0.05, 0.9)
@export_range(0, 32) var outline_size: int = 6
## Monospace font used for the art.
@export var font_names: PackedStringArray = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New", "monospace"])
## Font weight (100..999; bold glyphs read better over the floor glyphs).
@export_range(100, 999) var font_weight: int = 700
## Font size the art is rasterised at (the world size comes from the footprint, not from this).
@export_range(8, 128) var font_size: int = 32
## Width of the art as a fraction of the footprint width (1 = exactly as wide as the object's cells).
@export_range(0.1, 2.0) var art_width_ratio: float = 1.0
## Vertical offset of the bottom of the art, in world units (negative sinks it into the floor).
@export var art_lift: float = 0.0

@export_group("Animation")
## Animated layers: layer char -> glyph cycle. Every glyph of such a layer cycles through it, the phase shifted one
## step per row (and every other column) so the pattern flows downward, e.g. falling water. Empty: no animation.
@export var layer_anims: Dictionary[String, String] = {}
## Animation steps per second (low on purpose: every step rebuilds the text of the animated labels).
@export_range(0.0, 30.0) var anim_fps: float = 5.0

@export_group("Reveal")
## Colour multiplier while the object is only remembered (memory style).
@export var memory_tint: Color = Color(0.35, 0.38, 0.55, 0.75)
## Seconds the art takes to fade between hidden / remembered / seen.
@export var reveal_fade: float = 0.6

@export_group("Gameplay")
## Height of the collision box (world units).
@export var height: float = 1.0
## The object has a collision box over its whole footprint.
@export var blocks_movement: bool = true
## Its cells hide what is behind them from discovery (MapReveal line of sight); they are seen themselves.
@export var blocks_sight: bool = true
## Its cells block light (GlyphLightOcclusion).
@export var blocks_light: bool = true
## A cannon ball (or any Destructibles hitter) destroys it (task-073, LargeObjects). Indestructible objects make balls bounce.
@export var destructible: bool = false


## Layer char of the art glyph at (col, row).
func layer_at(col: int, row: int) -> String:
	if row < 0 or row >= mask_lines.size():
		return " "
	var line: String = mask_lines[row]
	if col < 0 or col >= line.length():
		return " "
	return line[col]


## Every layer used by a non-space art glyph, in first-use order (base layer first when used).
func layers() -> PackedStringArray:
	var out := PackedStringArray()
	for row in art_lines.size():
		var line: String = art_lines[row]
		for col in line.length():
			if line[col] == " ":
				continue
			var layer: String = layer_at(col, row)
			if not out.has(layer):
				out.append(layer)
	out.sort()
	return out


func color_of(layer: String) -> Color:
	return layer_colors.get(layer, base_color)


## Text of one layer: the art with every glyph of other layers replaced by a space (rows keep their width so all
## layers line up in a monospace font). An animated layer replaces its glyphs with its cycle at `step`.
func layer_text(layer: String, step: int) -> String:
	var width: int = 0
	for line in art_lines:
		width = maxi(width, line.length())
	var cycle: String = layer_anims.get(layer, "")
	var rows := PackedStringArray()
	for row in art_lines.size():
		var line: String = art_lines[row]
		var out: String = ""
		for col in width:
			var ch: String = line[col] if col < line.length() else " "
			if ch == " " or layer_at(col, row) != layer:
				out += " "
			elif cycle != "":
				out += cycle[posmod(row - step + col % 2, cycle.length())]
			else:
				out += ch
		rows.append(out)
	return "\n".join(rows)


## Number of distinct animation steps of a layer (its cycle length; 1 for a static layer).
func layer_steps(layer: String) -> int:
	return maxi((layer_anims.get(layer, "") as String).length(), 1)


## True when any layer animates.
func is_animated() -> bool:
	for layer: String in layer_anims:
		if (layer_anims[layer] as String).length() > 1:
			return true
	return false
