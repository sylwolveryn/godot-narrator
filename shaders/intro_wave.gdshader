shader_type canvas_item;
// Intro: black veil plus an abstract wave drawn as halftone dots on a cell grid, with a soft glow halo.
// Driven by IntroSequence (veil, envelope, time, wave_color) and IntroConfig (the rest).
// Potato budget: one pass, no texture reads, no extra passes; the glow adds two sin() and one exp() per line
// and pixel (skipped entirely when glow_strength is 0). Only drawn while the intro is up.

uniform float veil : hint_range(0.0, 1.0) = 1.0;
uniform float envelope : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;
uniform vec4 wave_color : source_color = vec4(0.55, 0.9, 0.7, 1.0);
uniform int line_count = 5;
uniform float frequency = 2.2;
uniform float speed = 1.6;
uniform float amplitude = 0.14;
uniform float line_spacing = 0.05;
uniform float thickness = 0.03;
uniform vec2 cell_px = vec2(10.0, 18.0);
uniform float glow_strength = 0.5;
uniform float glow_width = 1.6;

void fragment() {
	vec2 px = FRAGCOORD.xy;
	vec2 cell = floor(px / cell_px);
	vec2 local = px / cell_px - cell - 0.5;
	vec2 cuv = (cell + 0.5) * cell_px * SCREEN_PIXEL_SIZE;
	vec2 uv = px * SCREEN_PIXEL_SIZE;

	float bright = 0.0;
	float glow = 0.0;
	float inv_glow = 1.0 / max(glow_width, 0.001);
	for (int i = 0; i < 12; i++) {
		if (i >= line_count) {
			break;
		}
		float fi = float(i) - float(line_count - 1) * 0.5;
		float phase = time * speed * (1.0 + 0.15 * float(i));
		float y = 0.5 + fi * line_spacing
			+ amplitude * sin(cuv.x * frequency * 6.28318 + phase + fi * 0.6)
			+ amplitude * 0.4 * sin(cuv.x * frequency * 2.7 * 6.28318 - phase * 1.3);
		float d = abs(cuv.y - y) / thickness;
		bright += exp(-d * d);
		if (glow_strength > 0.0) {
			// Halo: the same curve evaluated at the pixel (not the cell centre) so it is smooth in both axes;
			// exponential (not gaussian) falloff so it reaches further than the dots.
			float yg = 0.5 + fi * line_spacing
				+ amplitude * sin(uv.x * frequency * 6.28318 + phase + fi * 0.6)
				+ amplitude * 0.4 * sin(uv.x * frequency * 2.7 * 6.28318 - phase * 1.3);
			glow += exp(-abs(uv.y - yg) / thickness * inv_glow);
		}
	}
	// Soft fade toward the left and right screen edges so the wave floats.
	float edge = smoothstep(0.0, 0.2, cuv.x) * smoothstep(1.0, 0.8, cuv.x);
	bright = clamp(bright * envelope * edge, 0.0, 1.0);
	// Soft saturation: overlapping halos of neighbouring lines do not burn out to a flat sheet.
	float halo = (1.0 - exp(-glow)) * glow_strength * envelope * smoothstep(0.0, 0.2, uv.x) * smoothstep(1.0, 0.8, uv.x);

	// Halftone: dot radius grows with brightness.
	float dist = length(local * vec2(1.0, cell_px.x / cell_px.y));
	float dot_mask = smoothstep(bright * 0.55, bright * 0.55 - 0.12, dist) * step(0.02, bright);
	// Hot core: the dot centres bleach slightly toward white, the halo stays the pure hue.
	vec3 dot_col = mix(wave_color.rgb, vec3(1.0), 0.25 * dot_mask * bright);
	vec3 col = dot_col * dot_mask + wave_color.rgb * halo * (1.0 - dot_mask);
	COLOR = vec4(col, max(veil, max(dot_mask, halo)));
}
