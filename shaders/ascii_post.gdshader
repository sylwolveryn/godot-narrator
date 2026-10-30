shader_type canvas_item;
// Converts the rendered screen into ASCII glyphs. Uniforms are set by AsciiPostProcess.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D glyph_atlas : filter_nearest;
uniform vec2 cell_px = vec2(10.0, 18.0);
uniform int glyph_count = 10;
uniform vec4 fg_color : source_color = vec4(0.85, 0.95, 0.85, 1.0);
uniform vec4 bg_color : source_color = vec4(0.02, 0.03, 0.02, 1.0);
uniform float scene_color_mix = 0.0;
uniform float brightness_gain = 1.6;

void fragment() {
	vec2 px = FRAGCOORD.xy;
	vec2 cell = floor(px / cell_px);
	vec2 local = floor(px - cell * cell_px);
	vec2 origin = cell * cell_px;

	// Average a 3x3 grid of samples across the cell.
	vec3 sum = vec3(0.0);
	for (int y = 0; y < 3; y++) {
		for (int x = 0; x < 3; x++) {
			vec2 p = origin + cell_px * (vec2(float(x), float(y)) + 0.5) / 3.0;
			sum += texture(screen_tex, p * SCREEN_PIXEL_SIZE).rgb;
		}
	}
	vec3 avg = sum / 9.0;
	float lum = clamp(dot(avg, vec3(0.299, 0.587, 0.114)) * brightness_gain, 0.0, 1.0);

	int idx = int(floor(lum * float(glyph_count - 1) + 0.5));
	vec2 uv = vec2((float(idx) * cell_px.x + local.x + 0.5) / (float(glyph_count) * cell_px.x),
			(local.y + 0.5) / cell_px.y);
	float mask = texture(glyph_atlas, uv).r;

	vec3 glyph_col = mix(fg_color.rgb, normalize(avg + vec3(0.0001)) * 1.2, scene_color_mix);
	COLOR = vec4(mix(bg_color.rgb, glyph_col, mask), 1.0);
}
