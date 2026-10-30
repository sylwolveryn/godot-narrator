extends SceneTree
## Dev tool: bakes the SDF glyph atlas on the GPU and writes it as a PNG (visual check of the bake).
## Needs a GPU, so it is NOT run headless:
##   godot --path . --resolution 640x360 -s tools/dump_atlas.gd -- <out.png>

var _atlas := GlyphAtlas.new()


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var config: AsciiConfig = load("res://resources/config/ascii_config.tres")
	for i in 5:
		await process_frame
	var t0: int = Time.get_ticks_usec()
	await _atlas.bake(root, config)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://atlas.png"
	var img: Image = _atlas.texture.get_image()
	var circle: int = _atlas.index_of(GlyphAtlas.CIRCLE)
	var cx: int = (circle % _atlas.columns) * _atlas.tile_px.x + _atlas.tile_px.x / 2
	var cy: int = (circle / _atlas.columns) * _atlas.tile_px.y + _atlas.tile_px.y / 2
	print("CIRCLE centre value ", img.get_pixel(cx, cy), " edge ", img.get_pixel(cx + 12, cy), " ", img.get_pixel(cx + 13, cy), " ", img.get_pixel(cx + 14, cy), " out ", img.get_pixel(cx + 20, cy), " format ", img.get_format())
	var gray := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_L8)
	for y in img.get_height():
		for x in img.get_width():
			gray.set_pixel(x, y, Color(img.get_pixel(x, y).r, img.get_pixel(x, y).r, img.get_pixel(x, y).r))
	img = gray
	img.save_png(out)
	_atlas.debug_raster.save_png(out.get_basename() + "_raster.png")
	print("ATLAS %dx%d tiles %dx%d cols %d glyphs %d bake %.1f ms -> %s" % [img.get_width(), img.get_height(),
			_atlas.tile_px.x, _atlas.tile_px.y, _atlas.columns, GlyphAtlas.characters_for(config).size(), ms, out])
	quit()
