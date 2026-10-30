class_name GlyphAtlas
extends RefCounted
## Signed-distance-field glyph atlas shared by the world post-process and the overlay
## `glyph_morph` shader (docs/visual_direction.md section 1).
## Baked once at boot, on the GPU: glyphs are drawn white on black into a SubViewport at a
## supersampled size, a brute-force distance pass (shaders/glyph_sdf_bake.gdshader) turns them
## into an R8 distance field, and the result becomes an ImageTexture. Resolution independent:
## the atlas never has to be rebuilt when the window size changes.
## Value 0.5 is the glyph edge, 1.0 is `sdf_spread_px` inside, 0.0 is `sdf_spread_px` outside.

## Character that stands for the analytic circle glyph.
const CIRCLE := "●"
const BLANK := " "
const BAKE_SHADER := "res://shaders/glyph_sdf_bake.gdshader"

var texture: ImageTexture
var columns: int = 1
var rows: int = 1
## Tile size in atlas pixels.
var tile_px: Vector2i = Vector2i.ONE
## Tile size as a fraction of the whole atlas (the `atlas_tile_uv` shader uniform).
var tile_uv: Vector2 = Vector2.ONE
var ready: bool = false
## Last supersampled raster (kept only for tools/dump_atlas.gd).
var debug_raster: Image

var _index: Dictionary[String, int] = {}
var _chars: PackedStringArray = PackedStringArray()


## Every character the configuration needs, unique, blank first and circle last.
static func characters_for(config: AsciiConfig) -> PackedStringArray:
	var out := PackedStringArray()
	var seen: Dictionary[String, bool] = {}
	var text: String = BLANK + config.ramp_floor + config.ramp_wall + config.ramp_item \
			+ config.ramp_spikes + config.ramp_corruption + config.abstract_glyphs + CIRCLE
	for i in text.length():
		var ch: String = text[i]
		if not seen.has(ch):
			seen[ch] = true
			out.append(ch)
	return out


## Atlas index of a character (the blank glyph when unknown).
func index_of(ch: String) -> int:
	return _index.get(ch, 0)


## Sets the atlas uniforms on a ShaderMaterial that includes glyph_sdf.gdshaderinc.
func apply_to(material: ShaderMaterial) -> void:
	material.set_shader_parameter("glyph_atlas", texture)
	material.set_shader_parameter("atlas_cols", columns)
	material.set_shader_parameter("atlas_tile_uv", tile_uv)


## Bakes the atlas. `host` must be in the scene tree (it parents the temporary SubViewports).
func bake(host: Node, config: AsciiConfig) -> void:
	_chars = characters_for(config)
	_index.clear()
	for i in _chars.size():
		_index[_chars[i]] = i
	var aspect: float = float(config.cell_size.y) / float(config.cell_size.x)
	tile_px = Vector2i(config.atlas_glyph_px, roundi(config.atlas_glyph_px * aspect))
	columns = ceili(sqrt(float(_chars.size())))
	rows = ceili(float(_chars.size()) / float(columns))
	var atlas_px := Vector2i(columns * tile_px.x, rows * tile_px.y)
	tile_uv = Vector2(1.0 / columns, 1.0 / rows)
	var ss: int = config.atlas_supersample

	# Pass 1: white glyphs on black at supersampled size.
	var raster_vp := SubViewport.new()
	raster_vp.size = atlas_px * ss
	raster_vp.transparent_bg = false
	raster_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var canvas := _RasterCanvas.new()
	canvas.config = config
	canvas.font.font_names = config.font_names
	canvas.chars = _chars
	canvas.columns = columns
	canvas.tile = tile_px * ss
	raster_vp.add_child(canvas)
	host.add_child(raster_vp)
	# Two frames: font glyph textures are uploaded lazily, the first draw can still see blanks.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var raster: Image = raster_vp.get_texture().get_image()
	debug_raster = raster
	raster_vp.queue_free()
	raster.convert(Image.FORMAT_RGBA8)

	# Pass 2: distance field at final size.
	var sdf_vp := SubViewport.new()
	sdf_vp.size = atlas_px
	sdf_vp.transparent_bg = false
	sdf_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := ColorRect.new()
	rect.size = Vector2(atlas_px)
	var mat := ShaderMaterial.new()
	mat.shader = load(BAKE_SHADER) as Shader
	mat.set_shader_parameter("src", ImageTexture.create_from_image(raster))
	mat.set_shader_parameter("scale", ss)
	mat.set_shader_parameter("spread_px", float(config.sdf_spread_px))
	rect.material = mat
	sdf_vp.add_child(rect)
	host.add_child(sdf_vp)
	await RenderingServer.frame_post_draw
	var sdf: Image = sdf_vp.get_texture().get_image()
	sdf_vp.queue_free()
	sdf.convert(Image.FORMAT_R8)
	texture = ImageTexture.create_from_image(sdf)
	ready = true


## Draws every glyph, white on black, one per tile.
class _RasterCanvas extends Control:
	var config: AsciiConfig
	var chars: PackedStringArray
	var columns: int
	var tile: Vector2i
	## Kept as a member: a font freed at the end of _draw would leave the draw commands blank.
	var font: SystemFont

	func _init() -> void:
		font = SystemFont.new()
		font.font_weight = 700
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY

	func _draw() -> void:
		var rows: int = ceili(float(chars.size()) / float(columns))
		draw_rect(Rect2(Vector2.ZERO, Vector2(tile.x * columns, tile.y * rows)), Color.BLACK)
		var font_size: int = roundi(tile.x * config.atlas_font_scale)
		var ascent: float = font.get_ascent(font_size)
		var height: float = font.get_height(font_size)
		for i in chars.size():
			var ch: String = chars[i]
			if ch == GlyphAtlas.BLANK:
				continue
			var origin := Vector2(i % columns, i / columns) * Vector2(tile)
			if ch == GlyphAtlas.CIRCLE:
				draw_circle(origin + Vector2(tile) * 0.5, tile.y * 0.28, Color.WHITE)
				continue
			var w: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var pos := origin + Vector2((tile.x - w) * 0.5, (tile.y - height) * 0.5 + ascent)
			draw_string(font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
