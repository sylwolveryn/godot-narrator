shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_test_disabled, cull_disabled, skip_vertex_transform;
// Spike B: one MultiMesh draws every glyph quad. A morph is evaluated ENTIRELY here from per-instance
// start/end data and one uniform (morph_t), so the CPU does no per-frame per-glyph work.
//
// Instance data (12 transform floats are reused as raw data, the node transform is identity):
//   MODEL_MATRIX[0].xyz = end position        MODEL_MATRIX[3].xyz = start position
//   MODEL_MATRIX[1].xyz = (delay, duration, spin turns)   (delay < 0 means "static, already at the end")
//   MODEL_MATRIX[2].xyz = (arc height, glyph from, glyph to)
//   COLOR  = end colour (rgb) + alpha            INSTANCE_CUSTOM = (size0, size1, start colour code, glow)
// cpu_mode = 1 reads final per-frame values instead (computed in GDScript, for the cost comparison):
//   pos = MODEL_MATRIX[3], flip = MODEL_MATRIX[1].x, angle = MODEL_MATRIX[1].z, glyph = MODEL_MATRIX[2].y.

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 atlas_grid = vec2(16.0, 7.0);
uniform float morph_t = 100.0;
uniform float cpu_mode = 0.0;
uniform float halo_scale = 2.6;
uniform float halo_strength = 0.3;
uniform float pop = 0.45;
uniform float flash = 0.22;
uniform float wobble = 0.03;

varying vec4 v_col;
varying vec2 v_q;
varying float v_glyph;
varying float v_glow;

const float C1 = 1.35;
const float C3 = C1 + 1.0;

float ease_out_back(float x) {
	float y = x - 1.0;
	return 1.0 + C3 * y * y * y + C1 * y * y;
}

vec4 decode_colour(float code) {
	float z = floor(code + 0.5);
	float a = mod(z, 2.0);
	z = floor(z / 2.0);
	float b = mod(z, 32.0);
	z = floor(z / 32.0);
	float g = mod(z, 32.0);
	float r = floor(z / 32.0);
	return vec4(r, g, b, a * 31.0) / 31.0;
}

void vertex() {
	float seed = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
	vec3 wp;
	float size;
	float ang;
	float flip;
	float glyph;
	vec4 col;
	if (cpu_mode > 0.5) {
		wp = MODEL_MATRIX[3].xyz;
		flip = abs(MODEL_MATRIX[1].x);
		ang = MODEL_MATRIX[1].z;
		glyph = MODEL_MATRIX[2].y;
		size = INSTANCE_CUSTOM.x;
		col = COLOR;
	} else {
		vec3 p1 = MODEL_MATRIX[0].xyz;
		vec3 p0 = MODEL_MATRIX[3].xyz;
		float delay = MODEL_MATRIX[1].x;
		float dur = max(MODEL_MATRIX[1].y, 0.001);
		float spin = MODEL_MATRIX[1].z;
		float arc = MODEL_MATRIX[2].x;
		float u = delay < 0.0 ? 1.0 : clamp((morph_t - delay) / dur, 0.0, 1.0);
		float us = u * u * (3.0 - 2.0 * u);
		float e = ease_out_back(us);
		float a = seed * 6.2831853;
		float lift = sin(3.14159265 * u);
		wp = mix(p0, p1, e) + (vec3(0.0, 1.0, 0.0) * arc + vec3(cos(a), 0.0, sin(a)) * arc * 0.45) * lift;
		float settle = smoothstep(0.92, 1.0, u);
		wp.y += sin(TIME * 2.3 + seed * 40.0) * wobble * settle;
		size = mix(INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.y, us) * (1.0 + pop * lift);
		ang = spin * 6.2831853 * us;
		glyph = MODEL_MATRIX[2].y;
		flip = 1.0;
		if (abs(MODEL_MATRIX[2].y - MODEL_MATRIX[2].z) > 0.5) {
			float f = smoothstep(0.2, 0.8, u);
			glyph = f < 0.5 ? MODEL_MATRIX[2].y : MODEL_MATRIX[2].z;
			flip = max(abs(cos(3.14159265 * f)), 0.04);
		}
		vec4 c0 = decode_colour(INSTANCE_CUSTOM.z);
		col = mix(c0, COLOR, smoothstep(0.1, 0.9, u));
		col.rgb += vec3(flash * lift);
	}
	float hs = INSTANCE_CUSTOM.w > 0.0 ? halo_scale : 1.12;
	vec2 q = VERTEX.xy * hs;
	float cs = cos(ang);
	float sn = sin(ang);
	vec2 corner = vec2(cs * q.x * flip - sn * q.y, sn * q.x * flip + cs * q.y) * size;
	vec4 vp = VIEW_MATRIX * vec4(wp, 1.0);
	vp.xy += corner;
	POSITION = PROJECTION_MATRIX * vp;
	v_q = q;
	v_glyph = glyph;
	v_col = col;
	v_glow = INSTANCE_CUSTOM.w;
}

void fragment() {
	vec2 uv = v_q + vec2(0.5);
	float cov = 0.0;
	if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
		vec2 cell = vec2(mod(v_glyph, atlas_grid.x), floor(v_glyph / atlas_grid.x));
		vec2 inner = vec2(uv.x, 1.0 - uv.y) * 0.96 + vec2(0.02);
		cov = texture(atlas, (cell + inner) / atlas_grid).a;
	}
	float r = length(v_q);
	float halo = v_glow * halo_strength * pow(smoothstep(halo_scale * 0.5, 0.0, r), 2.2);
	float a = v_col.a;
	ALBEDO = (v_col.rgb * cov + v_col.rgb * halo) * a;
	ALPHA = cov * a;
}
