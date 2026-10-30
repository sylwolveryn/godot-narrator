shader_type canvas_item;
// Reusable glyph shader for overlay quads (player glyph, narration letters, fragments). Put it on a
// ColorRect: UV (0..1) is the glyph tile. The glyph is a continuous SDF blend (never a swap):
//   target = mix(glyph_b, glyph_c, retarget)      (the erosion target changes through a morph)
//   shape  = mix(glyph_a, target, morph)          (`morph` is already eased by the caller)
// Optional extras: slow domain warp (erosion), an angular slice (death fragments), an outline.
#include "res://shaders/glyph_sdf.gdshaderinc"

uniform sampler2D glyph_atlas : filter_linear;
uniform int atlas_cols = 8;
uniform vec2 atlas_tile_uv = vec2(0.125, 0.125);
uniform int glyph_a = 0;
uniform int glyph_b = 0;
uniform int glyph_c = 0;
uniform float morph : hint_range(0.0, 1.0) = 0.0;
uniform float retarget : hint_range(0.0, 1.0) = 0.0;
uniform vec3 core_color = vec3(1.0, 0.96, 0.9);
uniform vec3 glow_color = vec3(1.0, 0.7, 0.28);
uniform float glow_strength = 1.0;
uniform float glow_radius = 0.35;
uniform float edge_soft = 0.06;
uniform float alpha = 1.0;
// Mid-morph the glyph shrinks to this scale and glows `glow_boost` more (times `bump_amount`).
uniform float scale_dip = 0.92;
uniform float glow_boost = 0.15;
uniform float bump_amount = 1.0;
// Extra margin around the tile (share of the tile size) so the halo can fade out smoothly.
uniform float uv_pad = 0.0;
uniform vec4 outline_color = vec4(0.0);
uniform float outline_w = 0.0;
// Slow domain warp: amplitude (tile units), frequency (Hz, keep at or below 0.5) and a per-glyph phase.
uniform float warp_amp = 0.0;
uniform float warp_hz = 0.35;
uniform float warp_seed = 0.0;
// Angular slice of the glyph (death fragments): centre angle and half width in radians.
uniform bool slice_on = false;
uniform float slice_mid = 0.0;
uniform float slice_half = 3.14159;

void fragment() {
	vec2 uv = (UV - 0.5) * (1.0 + 2.0 * uv_pad) + 0.5;
	float bump = max(morph_bump(morph), morph_bump(retarget)) * bump_amount;
	float s = 1.0 - (1.0 - scale_dip) * bump;
	vec2 local = (uv - 0.5) / s + 0.5;
	if (warp_amp > 0.0) {
		float ph = TAU * warp_hz * TIME;
		local += warp_amp * vec2(sin(ph + local.y * 4.0 + warp_seed), sin(ph * 0.83 + local.x * 5.0 + warp_seed * 1.7));
	}
	float da = glyph_sdf(glyph_atlas, atlas_cols, atlas_tile_uv, glyph_a, local);
	float d = da;
	if (morph > 0.0) {
		float db = glyph_sdf(glyph_atlas, atlas_cols, atlas_tile_uv, glyph_b, local);
		if (retarget > 0.0) {
			float dc = glyph_sdf(glyph_atlas, atlas_cols, atlas_tile_uv, glyph_c, local);
			db = mix(db, dc, retarget);
		}
		d = mix(da, db, morph);
	}
	float mask = 1.0;
	if (slice_on) {
		vec2 q = uv - 0.5;
		float diff = abs(mod(atan(q.y, q.x) - slice_mid + PI, TAU) - PI);
		mask = 1.0 - smoothstep(slice_half - 0.04, slice_half + 0.04, diff);
	}
	// Fade the halo to nothing at the edge of the padded quad.
	vec2 edge = min(UV, 1.0 - UV);
	float pad_fade = uv_pad > 0.0 ? smoothstep(0.0, uv_pad / (1.0 + 2.0 * uv_pad), min(edge.x, edge.y)) : 1.0;
	float cover = glyph_alpha(d, edge_soft) * mask;
	float halo = exp(-max(0.5 - d, 0.0) * 2.0 / glow_radius) * glow_strength * (1.0 + glow_boost * bump) * mask * pad_fade;
	float rim = outline_w > 0.0 ? glyph_alpha(d + outline_w, edge_soft) * outline_color.a * mask : 0.0;
	vec3 rgb = glow_color * halo;
	float a = halo * 0.6;
	rgb = mix(rgb, outline_color.rgb, rim);
	a = max(a, rim);
	rgb = mix(rgb, core_color, cover);
	a = max(a, cover);
	COLOR = vec4(rgb, clamp(a, 0.0, 1.0) * alpha);
}
