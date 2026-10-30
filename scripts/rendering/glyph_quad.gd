class_name GlyphQuad
extends ColorRect
## One overlay glyph drawn by shaders/glyph_morph.gdshader from the shared SDF atlas. The quad has
## the size of an atlas tile scaled to the wanted font size, so a glyph morph never reflows text.
## Presentation only: owners drive it through the setters below (never per-frame random).

const SHADER := "res://shaders/glyph_morph.gdshader"

var atlas: GlyphAtlas
var _material: ShaderMaterial
var _pad: float = 0.0


## Creates the material and binds the atlas. Call once after construction.
func setup(shared_atlas: GlyphAtlas) -> GlyphQuad:
	atlas = shared_atlas
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER) as Shader
	atlas.apply_to(_material)
	material = _material
	return self


## Sizes the quad (an atlas tile plus the halo padding) for glyphs drawn at `font_px` pixels.
func fit_to_font(font_px: float) -> void:
	size = Vector2(atlas.tile_px) * (font_px / atlas.font_px) * (1.0 + 2.0 * _pad)
	pivot_offset = size * 0.5


## Places the quad so that its centre is at `point`.
func centre_on(point: Vector2) -> void:
	position = (point - size * 0.5).round()


## The glyph shape: `a` morphs toward `b` by `amount`; `c` is the next target for a retarget morph.
func set_shape(a: int, b: int = 0, amount: float = 0.0, c: int = 0, retarget: float = 0.0) -> void:
	_material.set_shader_parameter("glyph_a", a)
	_material.set_shader_parameter("glyph_b", b)
	_material.set_shader_parameter("glyph_c", c)
	_material.set_shader_parameter("morph", clampf(amount, 0.0, 1.0))
	_material.set_shader_parameter("retarget", clampf(retarget, 0.0, 1.0))


## Only the blend amount (the glyphs stay).
func set_morph_amount(amount: float) -> void:
	_material.set_shader_parameter("morph", clampf(amount, 0.0, 1.0))


func set_colors(core: Color, glow: Color, glow_strength: float, glow_radius: float) -> void:
	_material.set_shader_parameter("core_color", Vector3(core.r, core.g, core.b))
	_material.set_shader_parameter("glow_color", Vector3(glow.r, glow.g, glow.b))
	_material.set_shader_parameter("glow_strength", glow_strength)
	_material.set_shader_parameter("glow_radius", glow_radius)


func set_alpha(value: float) -> void:
	_material.set_shader_parameter("alpha", value)


## Dark rim around the letters (SDF units) that keeps them legible over bright glyphs.
func set_outline(color_rgba: Color, width: float) -> void:
	_material.set_shader_parameter("outline_color", color_rgba)
	_material.set_shader_parameter("outline_w", width)


## Mid-morph scale dip, glow boost and how strongly they apply (0 turns them off).
func set_bump(scale_dip: float, glow_boost: float, amount: float = 1.0) -> void:
	_material.set_shader_parameter("scale_dip", scale_dip)
	_material.set_shader_parameter("glow_boost", glow_boost)
	_material.set_shader_parameter("bump_amount", amount)


## Halo padding around the tile (share of the tile size); call before fit_to_font.
func set_pad(pad: float) -> void:
	_pad = pad
	_material.set_shader_parameter("uv_pad", pad)


func set_edge(soft: float) -> void:
	_material.set_shader_parameter("edge_soft", soft)


func set_warp(amplitude: float, hz: float, seed_value: float) -> void:
	_material.set_shader_parameter("warp_amp", amplitude)
	_material.set_shader_parameter("warp_hz", hz)
	_material.set_shader_parameter("warp_seed", seed_value)


## Shows only an angular slice of the glyph (death fragments).
func set_slice(mid_angle: float, half_width: float) -> void:
	_material.set_shader_parameter("slice_on", true)
	_material.set_shader_parameter("slice_mid", mid_angle)
	_material.set_shader_parameter("slice_half", half_width)


func clear_slice() -> void:
	_material.set_shader_parameter("slice_on", false)
