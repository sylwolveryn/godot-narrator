extends SceneTree
## Builds res://resources/glyphs/glyph_surface_material.tres: the glyph-surface ShaderMaterial of the world
## mesh (shader + glyph atlas). Its other uniforms are set at runtime by GlyphWorldView from GlyphWorldConfig.
## Run after the atlas import: godot --headless --path . --max-fps 30 -s tools/build_glyph_material.gd
const SHADER := "res://shaders/glyph_surface.gdshader"
const OUT := "res://resources/glyphs/glyph_surface_material.tres"


func _init() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER) as Shader
	mat.set_shader_parameter(&"glyph_atlas", load(GlyphAtlasSpec.ATLAS_PATH) as Texture2D)
	var uid: int = ResourceLoader.get_resource_uid(OUT)
	var err: int = ResourceSaver.save(mat, OUT)
	if err == OK and uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(OUT, uid)
	print("Saved %s err=%d" % [OUT, err])
	quit(0 if err == OK else 1)
