class_name AsciiPostProcess
extends CanvasLayer
## Full-screen ASCII post-process. Owns a ColorRect (child "Screen") that carries the
## ascii_post shader. The glyph atlas is rasterised once from the configured font.

@export var config: AsciiConfig

@onready var _screen: ColorRect = $Screen


func _ready() -> void:
	if config == null:
		config = AsciiConfig.new()
	await _build_atlas_and_apply()


## Enables or disables the effect at runtime (debug toggle).
func set_enabled(value: bool) -> void:
	config.enabled = value
	_screen.visible = value


func _build_atlas_and_apply() -> void:
	_screen.visible = config.enabled
	var count: int = config.glyph_ramp.length()
	if count < 2:
		push_error("AsciiConfig.glyph_ramp needs at least 2 glyphs.")
		return
	var atlas := await _rasterise_atlas()
	var mat := _screen.material as ShaderMaterial
	mat.set_shader_parameter("glyph_atlas", atlas)
	mat.set_shader_parameter("cell_px", Vector2(config.cell_size))
	mat.set_shader_parameter("glyph_count", count)
	mat.set_shader_parameter("fg_color", config.foreground_color)
	mat.set_shader_parameter("bg_color", config.background_color)
	mat.set_shader_parameter("scene_color_mix", config.scene_color_mix)
	mat.set_shader_parameter("brightness_gain", config.brightness_gain)


## Draws every ramp glyph into a one-row SubViewport and copies it into an ImageTexture.
func _rasterise_atlas() -> ImageTexture:
	var count: int = config.glyph_ramp.length()
	var font := SystemFont.new()
	font.font_names = config.font_names
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY

	var vp := SubViewport.new()
	vp.size = Vector2i(config.cell_size.x * count, config.cell_size.y)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas := _AtlasCanvas.new()
	canvas.font = font
	canvas.ramp = config.glyph_ramp
	canvas.cell = config.cell_size
	canvas.font_size = config.font_size
	vp.add_child(canvas)
	add_child(vp)
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	img.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(img)


## Helper node that paints white glyphs on black, one per cell.
class _AtlasCanvas extends Control:
	var font: Font
	var ramp: String
	var cell: Vector2i
	var font_size: int

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(cell.x * ramp.length(), cell.y)), Color.BLACK)
		var ascent: float = font.get_ascent(font_size)
		var height: float = font.get_height(font_size)
		for i in ramp.length():
			var ch := ramp[i]
			var w: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var x: float = i * cell.x + (cell.x - w) * 0.5
			var y: float = (cell.y - height) * 0.5 + ascent
			draw_string(font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
