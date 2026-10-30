extends SceneTree
## Bakes resources/glyphs/glyph_atlas.png (layout: scripts/rendering/glyph_atlas_spec.gd), the
## glyph atlas of the glyph-surface material: white glyphs on black, one row per surface type.
## Needs a renderer (SubViewport raster), so it is the one tool that cannot run --headless:
##   godot --path . --max-fps 30 -s tools/build_glyph_atlas.gd
## Then re-import: godot --headless --path . --import --quit  (the .import file enables mipmaps).


class Painter extends Node2D:
	var font: Font

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(GlyphAtlasSpec.COLUMNS, GlyphAtlasSpec.ROWS) * GlyphAtlasSpec.CELL_PX), Color.BLACK)
		var cell: float = float(GlyphAtlasSpec.CELL_PX)
		for row in GlyphAtlasSpec.ROWS:
			var glyphs: String = GlyphAtlasSpec.ROW_GLYPHS[row]
			for col in GlyphAtlasSpec.COLUMNS:
				var ch: String = glyphs[col]
				if ch == " ":
					continue
				var adv: float = font.get_char_size(ch.unicode_at(0), GlyphAtlasSpec.FONT_PX).x
				var pos := Vector2(col * cell + (cell - adv) * 0.5,
						row * cell + cell * 0.5 + GlyphAtlasSpec.FONT_PX * GlyphAtlasSpec.BASELINE_DROP)
				font.draw_char(get_canvas_item(), pos, ch.unicode_at(0), GlyphAtlasSpec.FONT_PX, Color.WHITE)


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	var vp := SubViewport.new()
	vp.size = Vector2i(GlyphAtlasSpec.COLUMNS, GlyphAtlasSpec.ROWS) * GlyphAtlasSpec.CELL_PX
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var painter := Painter.new()
	painter.font = font
	vp.add_child(painter)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var err: int = img.save_png(ProjectSettings.globalize_path(GlyphAtlasSpec.ATLAS_PATH))
	print("ATLAS saved %s size=%s err=%d" % [GlyphAtlasSpec.ATLAS_PATH, img.get_size(), err])
	quit(0 if err == OK else 1)
