shader_type canvas_item;
// Reusable glyph shader for overlay quads (player glyph, narration letters, death fragments).
// Put it on a ColorRect / TextureRect: UV (0..1) is the glyph tile. The glyph is a continuous
// SDF blend of glyph_a into glyph_b (never a swap). `morph` is already eased by the caller.
#include "res://shaders/glyph_sdf.gdshaderinc"

uniform sampler2D glyph_atlas : filter_linear;
uniform int atlas_cols = 8;
uniform vec2 atlas_tile_uv = vec2(0.125, 0.125);
uniform int glyph_a = 0;
uniform int glyph_b = 0;
uniform float morph : hint_range(0.0, 1.0) = 0.0;
uniform vec3 core_color = vec3(1.0, 0.96, 0.9);
uniform vec3 glow_color = vec3(1.0, 0.7, 0.28);
uniform float glow_strength = 1.0;
uniform float glow_radius = 0.35;
uniform float edge_soft = 0.06;
uniform float alpha = 1.0;
// Mid-morph the glyph shrinks to this scale and glows `glow_boost` more.
uniform float scale_dip = 0.92;
uniform float glow_boost = 0.15;

void fragment() {
	float bump = morph_bump(morph);
	float s = 1.0 - (1.0 - scale_dip) * bump;
	vec2 local = (UV - 0.5) / s + 0.5;
	float d = glyph_sdf_morph(glyph_atlas, atlas_cols, atlas_tile_uv, glyph_a, glyph_b, morph, local);
	float cover = glyph_alpha(d, edge_soft);
	float halo = exp(-max(0.5 - d, 0.0) * 2.0 / glow_radius) * glow_strength * (1.0 + glow_boost * bump);
	vec3 rgb = mix(glow_color * halo, core_color, cover);
	float a = clamp(max(cover, halo * 0.6), 0.0, 1.0) * alpha;
	COLOR = vec4(rgb, a);
}
