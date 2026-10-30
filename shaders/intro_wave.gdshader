shader_type canvas_item;
// Intro: black veil plus an abstract wave drawn as halftone dots on a cell grid.
// Driven by IntroSequence (veil, envelope, time) and IntroConfig (the rest).

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

void fragment() {
	vec2 px = FRAGCOORD.xy;
	vec2 cell = floor(px / cell_px);
	vec2 local = px / cell_px - cell - 0.5;
	vec2 cuv = (cell + 0.5) * cell_px * SCREEN_PIXEL_SIZE;

	float bright = 0.0;
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
	}
	// Soft fade toward the left and right screen edges so the wave floats.
	float edge = smoothstep(0.0, 0.2, cuv.x) * smoothstep(1.0, 0.8, cuv.x);
	bright = clamp(bright * envelope * edge, 0.0, 1.0);

	// Halftone: dot radius grows with brightness.
	float dist = length(local * vec2(1.0, cell_px.x / cell_px.y));
	float dot_mask = smoothstep(bright * 0.55, bright * 0.55 - 0.12, dist) * step(0.02, bright);
	COLOR = vec4(wave_color.rgb * dot_mask, max(veil, dot_mask));
}
