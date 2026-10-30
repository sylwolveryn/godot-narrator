extends SceneTree
## Spike B builder: writes res://scenes/spikes/glyph_morph/glyph_morph.tscn (headless, idempotent).
##   godot --headless --path . -s tools/build_spike_glyph_morph.gd
const DIR := "res://scenes/spikes/glyph_morph/"
const OUT := DIR + "glyph_morph.tscn"


func _init() -> void:
	var root := Node3D.new()
	root.name = "GlyphMorph"
	root.set_script(load(DIR + "glyph_morph_demo.gd"))

	var cam := Camera3D.new()
	cam.name = "Camera"
	root.add_child(cam)
	cam.owner = root

	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	var fmat := ShaderMaterial.new()
	fmat.shader = load(DIR + "glyph_floor.gdshader")
	plane.material = fmat
	floor_mesh.mesh = plane
	root.add_child(floor_mesh)
	floor_mesh.owner = root

	var glyphs := MultiMeshInstance3D.new()
	glyphs.name = "Glyphs"
	glyphs.set_script(load(DIR + "glyph_morph_field.gd"))
	var gmat := ShaderMaterial.new()
	gmat.shader = load(DIR + "glyph_morph.gdshader")
	glyphs.set("glyph_material", gmat)
	glyphs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glyphs)
	glyphs.owner = root

	var hud := CanvasLayer.new()
	hud.name = "Hud"
	root.add_child(hud)
	hud.owner = root
	var label := Label.new()
	label.name = "Label"
	label.position = Vector2(16.0, 12.0)
	label.add_theme_font_size_override("font_size", 16)
	hud.add_child(label)
	label.owner = root

	var packed := PackedScene.new()
	var err: int = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("BUILD %s err=%d" % [OUT, err])
	root.free()
	quit(0 if err == OK else 1)
