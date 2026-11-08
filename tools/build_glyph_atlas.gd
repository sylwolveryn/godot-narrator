extends SceneTree
## Bakes resources/glyphs/glyph_atlas.png (layout: scripts/rendering/glyph_atlas_spec.gd), the FALLBACK glyph atlas of
## the glyph-surface material: white glyphs on black, one row per surface. The glyphs are the `glyph_ramp` rows of the
## bundled seed (data/db/seed.json, task-079), drawn by GlyphRampAtlas exactly as the game draws them at runtime.
## Needs a renderer (SubViewport raster), so it is the one tool that cannot run --headless:
##   godot --path . --max-fps 30 -s tools/build_glyph_atlas.gd
## Then re-import: godot --headless --path . --import --quit  (the .import file enables mipmaps).

const SEED_PATH := "res://data/db/seed.json"


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var seed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEED_PATH))
	var rows: Dictionary = GlyphRampAtlas.rows_from_table(seed.get(GlyphRampAtlas.TABLE, []) if seed is Dictionary else [])
	if rows.size() < GlyphAtlasSpec.ROWS:
		printerr("ATLAS seed has %d of %d glyph_ramp rows" % [rows.size(), GlyphAtlasSpec.ROWS])
		quit(1)
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(GlyphAtlasSpec.COLUMNS, GlyphAtlasSpec.ROWS) * GlyphAtlasSpec.CELL_PX
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var painter := GlyphRampAtlas.Painter.new()
	painter.font = GlyphRampAtlas.make_font()
	painter.rows = rows
	vp.add_child(painter)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var err: int = img.save_png(ProjectSettings.globalize_path(GlyphAtlasSpec.ATLAS_PATH))
	print("ATLAS saved %s size=%s err=%d" % [GlyphAtlasSpec.ATLAS_PATH, img.get_size(), err])
	quit(0 if err == OK else 1)
