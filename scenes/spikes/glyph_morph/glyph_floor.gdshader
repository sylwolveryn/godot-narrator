shader_type spatial;
render_mode unshaded, cull_disabled;
// Spike B: dark isometric floor with a faint grid and a soft pool of light around the origin.

uniform vec3 base_colour : source_color = vec3(0.012, 0.016, 0.03);
uniform vec3 pool_colour : source_color = vec3(0.05, 0.09, 0.12);
uniform float grid_step = 0.7;
uniform float pool_radius = 9.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 g = abs(fract(v_world.xz / grid_step + vec2(0.5)) - vec2(0.5));
	float line = 1.0 - smoothstep(0.0, 0.035, min(g.x, g.y));
	float pool = pow(smoothstep(pool_radius, 0.0, length(v_world.xz)), 1.6);
	ALBEDO = base_colour + pool_colour * pool + vec3(0.03, 0.05, 0.07) * line * (0.3 + pool);
}
