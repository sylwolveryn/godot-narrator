// Ink trail of the player (task-057). ONE MultiMesh of quads lying flat on the floor, each an ink glyph from a small
// runtime atlas (InkTrailView). The quad is oriented so the glyph stands upright on screen (like the floor glyphs).
// Per instance: transform origin = drop centre, scale = half-size, INSTANCE_CUSTOM = (spawn clock, atlas column,
// size jitter 0..1, rotation 0..1), INSTANCE COLOR = tint (rgb, a = tint share; task-104 blood / void trail). Fading and spreading happen here from `now` (set once per frame), so the CPU only
// writes an instance when a drop is spawned. Ink colour with a faint luminous rim, premultiplied.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, fog_disabled;

const float TWO_PI = 6.2831853;

uniform sampler2D ink_atlas : filter_linear, repeat_disable;
uniform float atlas_cols = 8.0;
uniform float now = 0.0;                     // InkTrailView clock, seconds
uniform float lifetime = 0.7;
uniform float spread = 0.6;                  // growth while fading (share of the size)
uniform vec3 ink_color = vec3(0.42, 0.3, 1.0);
uniform vec3 rim_color = vec3(0.79, 0.72, 1.0);
uniform float ink_alpha = 0.9;
uniform float rim_strength = 0.8;
uniform float max_tilt = 0.35;               // rotation of a drop, fraction of a turn either way

varying vec2 q;
varying float fade;
varying flat float column;
varying vec4 tint;

void vertex() {
	float age = now - INSTANCE_CUSTOM.x;
	float t = clamp(age / max(lifetime, 0.001), 0.0, 1.0);
	fade = (age < 0.0 || age > lifetime) ? 0.0 : 1.0 - t * t;
	column = INSTANCE_CUSTOM.y;
	tint = COLOR;
	vec3 c = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz) * (0.75 + 0.5 * INSTANCE_CUSTOM.z) * (1.0 + spread * t);
	vec3 cam_r = INV_VIEW_MATRIX[0].xyz;
	vec3 cam_f = INV_VIEW_MATRIX[2].xyz;
	vec3 r = normalize(vec3(cam_r.x, 0.0, cam_r.z));
	vec3 f = normalize(vec3(cam_f.x, 0.0, cam_f.z));
	float a = (INSTANCE_CUSTOM.w - 0.5) * 2.0 * max_tilt * TWO_PI * 0.25;
	vec2 v = vec2(VERTEX.x * cos(a) - VERTEX.y * sin(a), VERTEX.x * sin(a) + VERTEX.y * cos(a));
	vec3 pos = fade > 0.0 ? c + (r * v.x - f * v.y) * size : vec3(0.0, -1000.0, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pos, 1.0);
	q = VERTEX.xy;
}

void fragment() {
	vec2 uv = vec2(q.x, -q.y) * 0.5 + 0.5;
	vec2 auv = vec2((column + uv.x) / atlas_cols, uv.y);
	float cov = texture(ink_atlas, auv).a;
	// a soft blot under the glyph so the ink reads as a stain, not only a letter
	float blot = (1.0 - smoothstep(0.15, 1.0, length(q))) * 0.35;
	float body = max(cov, blot) * ink_alpha * fade;
	vec3 ink = mix(ink_color, tint.rgb, tint.a);
	vec3 rim = mix(rim_color, mix(tint.rgb, vec3(1.0), 0.45), tint.a);
	vec3 rgb = ink * body + rim * cov * rim_strength * fade * fade;
	ALBEDO = rgb;
	ALPHA = body;
}
