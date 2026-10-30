// SPIKE A (task-027). The player marker: one camera-facing quad showing a single atlas glyph (row 5, column 0 = '@').
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D glyph_atlas : filter_linear_mipmap, repeat_disable;
uniform vec4 glyph_color : source_color = vec4(0.85, 1.0, 0.35, 1.0);
uniform float glyph_col = 0.0;
uniform float glyph_row = 5.0;
uniform float lift = 0.8;

varying vec2 q;

void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 r = INV_VIEW_MATRIX[0].xyz;
	vec3 u = INV_VIEW_MATRIX[1].xyz;
	vec3 to_cam = INV_VIEW_MATRIX[2].xyz;
	vec3 pos = c + r * VERTEX.x + u * VERTEX.y + to_cam * lift;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pos, 1.0);
	q = UV;
}

void fragment() {
	vec2 auv = vec2((glyph_col + 0.2 + q.x * 0.6) / 8.0, (glyph_row + 0.03 + q.y * 0.94) / 6.0);
	float cov = texture(glyph_atlas, auv).r;
	cov = clamp((cov - 0.08) * 1.6, 0.0, 1.0);
	ALBEDO = glyph_color.rgb * (0.8 + 0.2 * sin(TIME * 2.0));
	ALPHA = cov;
}
