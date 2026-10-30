// Shared helpers for the signed-distance-field glyph atlas (scripts/rendering/glyph_atlas.gd).
// The atlas is a grid of tiles, one glyph per tile; value 0.5 is the glyph edge, above it is inside.
// Used by the world post shader and by the reusable glyph_morph canvas shader.

// SDF value of glyph `index` at tile-local coordinates `local` (0..1 over the tile).
float glyph_sdf(sampler2D atlas, int cols, vec2 tile_uv, int index, vec2 local) {
	vec2 tile = vec2(float(index % cols), float(index / cols));
	return texture(atlas, (tile + clamp(local, vec2(0.0), vec2(1.0))) * tile_uv).r;
}

// Continuous shape blend between two glyphs: d = mix(sdfA, sdfB, t).
float glyph_sdf_morph(sampler2D atlas, int cols, vec2 tile_uv, int a, int b, float t, vec2 local) {
	float da = glyph_sdf(atlas, cols, tile_uv, a, local);
	if (t <= 0.0) {
		return da;
	}
	float db = glyph_sdf(atlas, cols, tile_uv, b, local);
	return mix(da, db, t);
}

// Coverage from an SDF value. `soft` is the half-width of the edge in SDF units; it never goes
// below the screen-space derivative, so thin strokes stay anti-aliased at any scale.
float glyph_alpha(float d, float soft) {
	float w = max(soft, fwidth(d) * 0.75);
	return smoothstep(0.5 - w, 0.5 + w, d);
}

// 0 at the ends of a morph, 1 in the middle: drives the scale dip and glow boost.
float morph_bump(float t) {
	return 4.0 * t * (1.0 - t);
}
