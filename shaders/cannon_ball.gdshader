// Cannon balls (task-073). ONE MultiMesh of camera-facing quads, each a glyph from a small runtime atlas
// (CannonBallView): the ball itself or one of its trail glyphs. Per instance: transform origin = glyph centre,
// scale = half-size, COLOR = tint, INSTANCE_CUSTOM = (opacity, atlas column, glow, 0). Premultiplied, unshaded.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D ball_atlas : filter_linear, repeat_disable;
uniform float atlas_cols = 4.0;
uniform vec3 rim_color = vec3(1.0, 0.98, 0.9);

varying vec2 q;
varying float alpha;
varying flat float column;
varying float glow;
varying vec3 tint;

void vertex() {
	alpha = INSTANCE_CUSTOM.x;
	column = INSTANCE_CUSTOM.y;
	glow = INSTANCE_CUSTOM.z;
	tint = COLOR.rgb;
	vec3 c = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 r = INV_VIEW_MATRIX[0].xyz;
	vec3 u = INV_VIEW_MATRIX[1].xyz;
	vec3 pos = alpha > 0.0 ? c + (r * VERTEX.x + u * VERTEX.y) * size : vec3(0.0, -1000.0, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pos, 1.0);
	q = VERTEX.xy;
}

void fragment() {
	vec2 uv = vec2(q.x, -q.y) * 0.5 + 0.5;
	float cov = texture(ball_atlas, vec2((column + uv.x) / atlas_cols, uv.y)).a;
	// a soft hot halo around the glyph
	float halo = (1.0 - smoothstep(0.0, 1.0, length(q))) * 0.45 * glow;
	float body = max(cov, halo) * alpha;
	vec3 rgb = tint * body + rim_color * cov * glow * 0.6 * alpha;
	ALBEDO = rgb;
	ALPHA = body;
}
