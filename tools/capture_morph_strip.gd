extends SceneTree
## Dev tool: renders one glyph morphing into another with the reusable glyph_morph canvas shader
## (shared SDF atlas) and saves the strip as a PNG. Needs a GPU, so it is NOT run headless:
##   godot --path . --resolution 1280x720 -s tools/capture_morph_strip.gd -- <out.png> [from] [to]
## Defaults: "#" morphs into "&" in 9 steps.

const STEPS := 9
const TILE_SCALE := 4.0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://morph_strip.png"
	var from_ch: String = args[1] if args.size() > 1 else "#"
	var to_ch: String = args[2] if args.size() > 2 else "&"
	var config: AsciiConfig = load("res://resources/config/ascii_config.tres")
	var atlas := GlyphAtlas.new()
	await atlas.bake(root, config)
	var tile := Vector2(atlas.tile_px) * TILE_SCALE
	var vp := SubViewport.new()
	vp.size = Vector2i(int(tile.x * STEPS), int(tile.y))
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var shader: Shader = load("res://shaders/glyph_morph.gdshader")
	for i in STEPS:
		var rect := ColorRect.new()
		rect.position = Vector2(tile.x * i, 0.0)
		rect.size = tile
		var mat := ShaderMaterial.new()
		mat.shader = shader
		atlas.apply_to(mat)
		mat.set_shader_parameter("glyph_a", atlas.index_of(from_ch))
		mat.set_shader_parameter("glyph_b", atlas.index_of(to_ch))
		var t: float = float(i) / float(STEPS - 1)
		mat.set_shader_parameter("morph", ease(t, -2.0))
		rect.material = mat
		vp.add_child(rect)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("MORPH_STRIP %s -> %s saved %s" % [from_ch, to_ch, out])
	quit()
