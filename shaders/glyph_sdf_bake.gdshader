shader_type canvas_item;
// One-off distance pass of the glyph atlas bake: reads the white-on-black glyph raster `src`
// (rasterised at `scale` times the final size) and writes a signed distance per output pixel:
// 0.5 on the glyph edge, 1.0 at `spread_px` inside, 0.0 at `spread_px` outside (output pixels).

uniform sampler2D src : filter_nearest;
uniform int scale = 2;
uniform float spread_px = 4.0;

const int MAX_RADIUS = 16;

void fragment() {
	ivec2 size = textureSize(src, 0);
	vec2 centre = (floor(FRAGCOORD.xy) + 0.5) * float(scale);
	ivec2 base = ivec2(floor(centre));
	int radius = int(ceil(spread_px * float(scale)));
	// Own class from the 2x2 raster pixels around the output pixel centre.
	float cover = 0.0;
	for (int y = -1; y <= 0; y++) {
		for (int x = -1; x <= 0; x++) {
			ivec2 p = clamp(base + ivec2(x, y), ivec2(0), size - 1);
			cover += texelFetch(src, p, 0).r;
		}
	}
	bool inside = cover * 0.25 > 0.5;
	float best = float(radius) + 1.0;
	for (int dy = -MAX_RADIUS; dy <= MAX_RADIUS; dy++) {
		if (abs(dy) > radius) {
			continue;
		}
		for (int dx = -MAX_RADIUS; dx <= MAX_RADIUS; dx++) {
			if (abs(dx) > radius) {
				continue;
			}
			ivec2 p = base + ivec2(dx, dy);
			bool other = false;
			if (p.x >= 0 && p.y >= 0 && p.x < size.x && p.y < size.y) {
				other = texelFetch(src, p, 0).r > 0.5;
			}
			if (other != inside) {
				best = min(best, length(vec2(p) + 0.5 - centre));
			}
		}
	}
	float d = (inside ? 1.0 : -1.0) * max(best - 0.5, 0.0) / float(scale);
	float v = clamp(0.5 + d / (2.0 * spread_px), 0.0, 1.0);
	COLOR = vec4(v, v, v, 1.0);
}
