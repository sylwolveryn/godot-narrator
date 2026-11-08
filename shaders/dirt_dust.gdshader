// Dust of an eaten dirt cell (task-070). ONE MultiMesh of small glyph quads (DirtView): each fragment is thrown up from
// the cell, falls under gravity, lands on the floor and fades. The glyph stands upright facing the camera.
// Per instance: transform origin = start point, scale = half-size, INSTANCE_CUSTOM = (spawn clock, atlas column,
// sideways velocity x, z). The motion runs here from `now` (set once per frame while dust is alive), so the CPU writes
// an instance only when it is spawned.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D dust_atlas : filter_linear, repeat_disable;
uniform float atlas_cols = 8.0;
uniform float now = 0.0;
uniform float lifetime = 0.65;
uniform float rise = 1.8;                    // upward start speed (varied per fragment)
uniform float gravity = 9.0;
uniform vec3 dust_color = vec3(0.95, 0.68, 0.38);
uniform vec3 rim_color = vec3(1.0, 0.85, 0.6);

varying vec2 q;
varying float fade;
varying flat float column;

void vertex() {
	float age = now - INSTANCE_CUSTOM.x;
	float t = clamp(age / max(lifetime, 0.001), 0.0, 1.0);
	fade = (age < 0.0 || age > lifetime) ? 0.0 : 1.0 - t * t;
	column = INSTANCE_CUSTOM.y;
	vec3 c0 = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	float vy = rise * (0.6 + 0.8 * fract(INSTANCE_CUSTOM.y * 0.618 + INSTANCE_CUSTOM.z * 3.7));
	float a = max(age, 0.0);
	vec3 c = c0 + vec3(INSTANCE_CUSTOM.z, vy, INSTANCE_CUSTOM.w) * a - vec3(0.0, 0.5 * gravity * a * a, 0.0);
	c.y = max(c.y, size);
	vec3 r = INV_VIEW_MATRIX[0].xyz;
	vec3 u = INV_VIEW_MATRIX[1].xyz;
	vec3 pos = fade > 0.0 ? c + (r * VERTEX.x + u * VERTEX.y) * size : vec3(0.0, -1000.0, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pos, 1.0);
	q = VERTEX.xy;
}

void fragment() {
	vec2 uv = vec2(q.x, -q.y) * 0.5 + 0.5;
	float cov = texture(dust_atlas, vec2((column + uv.x) / atlas_cols, uv.y)).a * fade;
	ALBEDO = dust_color * cov + rim_color * cov * fade * 0.5;
	ALPHA = cov;
}
