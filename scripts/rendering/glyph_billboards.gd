class_name GlyphBillboards
extends Node3D
## A pool of camera-facing glyph quads in ONE MultiMesh (shaders/cannon_ball.gdshader, the cannon balls' glyph
## billboard shader): the glyphs are rasterised once into a tiny runtime atlas. Owners (EnemyView, RemainsView) call
## begin(), put() every glyph of the frame, then end(): the live glyphs are the first instances and
## visible_instance_count is cut to them (nothing drawn when there are none). Presentation only.

const SHADER: String = "res://shaders/cannon_ball.gdshader"
const QUAD_EXTENT: float = 2.0

var _mm: MultiMesh
var _material: ShaderMaterial
var _viewport: SubViewport
var _columns: Dictionary[String, int] = {}
var _n: int = 0
## Glyphs drawn in the last frame (tests).
var drawn: int = 0


## Builds the atlas of `chars` (each character one column) and a pool of `capacity` quads.
func setup(chars: String, font_names: PackedStringArray, tile_px: int, font_px: int, capacity: int, rim: Color) -> void:
	var unique: String = ""
	for i in chars.length():
		var ch: String = chars[i]
		if not _columns.has(ch):
			_columns[ch] = unique.length()
			unique += ch
	var cols: int = maxi(unique.length(), 1)
	_viewport = SubViewport.new()
	_viewport.name = "GlyphAtlas"
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	_viewport.size = Vector2i(cols * tile_px, tile_px)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	var painter := InkTrailView.InkPainter.new()
	# The first installed font of the list draws; the others back it up glyph by glyph (e.g. Consolas lacks ◆ ●).
	var font := SystemFont.new()
	font.font_names = font_names
	var fallbacks: Array[Font] = []
	for name in font_names:
		var f := SystemFont.new()
		f.font_names = PackedStringArray([name])
		fallbacks.append(f)
	font.fallbacks = fallbacks
	painter.font = font
	painter.glyphs = unique
	painter.tile = tile_px
	painter.font_px = font_px
	_viewport.add_child(painter)
	var quad := QuadMesh.new()
	quad.size = Vector2(QUAD_EXTENT, QUAD_EXTENT)
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = quad
	_mm.instance_count = maxi(capacity, 1)
	_mm.visible_instance_count = 0
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER) as Shader
	_material.set_shader_parameter(&"ball_atlas", _viewport.get_texture())
	_material.set_shader_parameter(&"atlas_cols", float(cols))
	_material.set_shader_parameter(&"rim_color", Vector3(rim.r, rim.g, rim.b))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Glyphs"
	instance.multimesh = _mm
	instance.material_override = _material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-1.0e4, -10.0, -1.0e4), Vector3(2.0e4, 20.0, 2.0e4))
	add_child(instance)


func capacity() -> int:
	return _mm.instance_count if _mm != null else 0


## Atlas column of a character (0 when it is not in the atlas).
func column(ch: String) -> int:
	return _columns.get(ch, 0)


func begin() -> void:
	_n = 0


## Adds one glyph: centre `pos`, half-size `size`, tint, opacity, atlas column, glow 0..1. False when the pool is full.
func put(pos: Vector3, size: float, color: Color, alpha: float, col: int, glow: float) -> bool:
	if _mm == null or _n >= _mm.instance_count or alpha <= 0.0 or size <= 0.0:
		return false
	_mm.set_instance_transform(_n, Transform3D(Basis.from_scale(Vector3.ONE * size), pos))
	_mm.set_instance_color(_n, color)
	_mm.set_instance_custom_data(_n, Color(alpha, float(col), glow, 0.0))
	_n += 1
	return true


func end() -> void:
	if _mm == null:
		return
	if _mm.visible_instance_count != _n:
		_mm.visible_instance_count = _n
	drawn = _n
