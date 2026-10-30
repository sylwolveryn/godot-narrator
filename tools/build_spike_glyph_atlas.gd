extends SceneTree
## Spike B tool: bakes the glyph atlas PNG for scenes/spikes/glyph_morph (white glyphs on transparent).
## Needs a GPU (SubViewport render), so NOT headless:
##   godot --path . -s tools/build_spike_glyph_atlas.gd
const GlyphSet := preload("res://scenes/spikes/glyph_morph/glyph_set.gd")
const Painter := preload("res://scenes/spikes/glyph_morph/glyph_atlas_painter.gd")
const OUT := "res://scenes/spikes/glyph_morph/glyph_atlas.png"


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	var vp := SubViewport.new()
	vp.size = Vector2i(GlyphSet.COLUMNS * GlyphSet.CELL_PX, GlyphSet.rows() * GlyphSet.CELL_PX)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var painter: Node2D = Painter.new()
	painter.font = font
	vp.add_child(painter)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var err: int = img.save_png(ProjectSettings.globalize_path(OUT))
	print("ATLAS saved %s size=%s err=%d" % [OUT, img.get_size(), err])
	quit()
