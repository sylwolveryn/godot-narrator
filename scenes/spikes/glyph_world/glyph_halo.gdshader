// SPIKE A (task-027). Cheap additive halo billboards. ONE mesh holds every static halo (centre in VERTEX, corner in UV,
// size/phase in UV2, colour in COLOR), so all of them cost a single draw call. No screen texture, no post-process.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform float base_size = 0.0;     // added to UV2.x (used by the single-quad player halo)
uniform float lift = 1.0;          // pushes the quad towards the camera (x size) so the floor never clips it
uniform vec4 tint : source_color = vec4(1.0);

varying vec2 q;
varying vec4 hc;

void vertex() {
	vec3 c = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 corner = UV * 2.0 - 1.0;
	float size = UV2.x + base_size;
	float pulse = 1.0 + 0.07 * sin(TIME * 1.3 + UV2.y);
	vec3 r = INV_VIEW_MATRIX[0].xyz;
	vec3 u = INV_VIEW_MATRIX[1].xyz;
	vec3 to_cam = INV_VIEW_MATRIX[2].xyz;
	vec3 pos = c + (r * corner.x + u * corner.y) * size * pulse + to_cam * size * lift;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pos, 1.0);
	q = corner;
	hc = COLOR * tint;
}

void fragment() {
	float r2 = dot(q, q);
	float g = exp(-r2 * 4.5) * (1.0 - smoothstep(0.6, 1.0, sqrt(r2)));
	ALBEDO = hc.rgb;
	ALPHA = g * hc.a;
}
