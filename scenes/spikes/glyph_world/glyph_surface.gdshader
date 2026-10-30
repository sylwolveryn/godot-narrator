// SPIKE A (task-027). ONE shader for every world surface: glyphs live ON the faces (walls, floor, spikes, item, corruption).
// Glyph grid is derived from world space per face (top faces: screen-aligned axes, side faces: surface-aligned), so glyphs
// follow the geometry. Per cell: light is evaluated once at the cell centre, brightness picks the glyph from the type's density
// ramp (atlas row = type id in vertex COLOR.r*8), colour comes from a small per-type gradient tinted by the light colour.
// No shadows, no screen texture, no post-process. Cost: 1 atlas fetch (textureGrad) per fragment, no dependent reads, 1 loop of <=8 lights.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, fog_disabled;

const int MAX_LIGHTS = 8;
const float ATLAS_COLS = 8.0;
const float ATLAS_ROWS = 6.0;
const vec3 CAM_RIGHT = vec3(0.70710678, 0.0, -0.70710678);
const vec3 CAM_DOWN = vec3(0.70710678, 0.0, 0.70710678);
const float TOP_FORESHORTEN = 0.57735027;   // sin(35.264 deg): screen height of a unit step along CAM_DOWN
const float SIDE_HORIZ = 0.70710678;        // screen width of a unit step along a wall face
const float SIDE_VERT = 0.81649658;         // cos(35.264 deg): screen height of a unit step in Y

// Per type: 0 wall, 1 floor, 2 spikes, 3 corruption, 4 item.
const vec3 PAL_DARK[5] = vec3[5](vec3(0.20, 0.27, 0.45), vec3(0.24, 0.24, 0.34), vec3(0.45, 0.12, 0.10), vec3(0.30, 0.12, 0.55), vec3(0.10, 0.45, 0.75));
const vec3 PAL_BRIGHT[5] = vec3[5](vec3(0.60, 0.76, 1.00), vec3(1.00, 0.74, 0.44), vec3(1.00, 0.40, 0.22), vec3(1.00, 0.35, 0.90), vec3(0.75, 0.97, 1.00));
const float EMIT[5] = float[5](0.0, 0.0, 0.18, 0.38, 0.85);

uniform sampler2D glyph_atlas : filter_linear_mipmap, repeat_disable;
uniform float cell_screen = 0.19;      // glyph cell height on screen, in world units
uniform float cell_aspect = 0.62;      // glyph cell width / height
uniform float glyph_crop = 0.62;       // fraction of the atlas tile width shown per cell
uniform float wall_height = 1.6;
uniform vec4 slice_params = vec4(0.0, 0.0, 8.0, 6.0);   // centre xz, half extent xz (edge fade)
uniform vec4 light_pos[MAX_LIGHTS];    // xyz position, w radius
uniform vec4 light_col[MAX_LIGHTS];    // rgb colour * intensity
uniform int light_count = 1;
uniform float ambient_level = 0.30;
uniform float tint_mix = 0.75;

varying vec3 w_pos;
varying flat vec3 w_nrm;
varying flat float v_type;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = mat3(MODEL_MATRIX) * NORMAL;
	v_type = COLOR.r;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	int t = int(v_type * 8.0 + 0.5);
	bool top = abs(n.y) > 0.7;

	vec3 axu;
	vec3 axv;
	float cw;
	float chh;
	if (top) {
		axu = CAM_RIGHT;
		axv = CAM_DOWN;
		cw = cell_screen * cell_aspect;
		chh = cell_screen / TOP_FORESHORTEN;
	} else {
		vec3 nh = normalize(vec3(n.x, 0.0, n.z));
		axu = normalize(cross(-nh, vec3(0.0, 1.0, 0.0)));
		axv = vec3(0.0, -1.0, 0.0);
		cw = cell_screen * cell_aspect / SIDE_HORIZ;
		chh = cell_screen / SIDE_VERT;
	}
	vec2 uv = vec2(dot(w_pos, axu) / cw, dot(w_pos, axv) / chh);
	vec2 cell = floor(uv);
	vec2 loc = uv - cell;
	vec3 pc = w_pos + axu * ((cell.x + 0.5 - uv.x) * cw) + axv * ((cell.y + 0.5 - uv.y) * chh);

	// light at the cell centre
	float face_amb = top ? 1.0 : (n.z > 0.5 ? 0.7 : 0.45);
	vec3 lit = vec3(0.55, 0.65, 1.0) * ambient_level * face_amb;
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= light_count) {
			break;
		}
		vec3 L = light_pos[i].xyz - pc;
		float d = length(L);
		float att = clamp(1.0 - d / light_pos[i].w, 0.0, 1.0);
		float ndl = 0.45 + 0.55 * smoothstep(-0.15, 0.65, dot(n, L / max(d, 0.001)));
		lit += light_col[i].rgb * (att * ndl);
	}

	float h = hash12(cell + vec2(float(t) * 7.31, dot(n, vec3(1.7, 2.9, 3.3)) + floor(dot(w_pos, n) * 4.0)));
	float pulse = 0.04 * sin(TIME * 0.55 + h * 6.2832);
	float b = max(lit.r, max(lit.g, lit.b)) + EMIT[t] * (0.8 + 1.5 * pulse) + (h - 0.5) * 0.10 + pulse;
	if (!top && t == 0) {
		b += smoothstep(wall_height - 0.12, wall_height, w_pos.y) * 0.22;   // rim along wall tops
	}
	float s = clamp(b, 0.0, 0.999);
	float idx = min(1.0 + floor(pow(s, 0.65) * 7.0), 7.0);

	vec2 auv = vec2((idx + 0.5 + (loc.x - 0.5) * glyph_crop) / ATLAS_COLS, (float(t) + 0.03 + loc.y * 0.94) / ATLAS_ROWS);
	vec2 sc = vec2(glyph_crop / ATLAS_COLS, 0.94 / ATLAS_ROWS);
	float cov = textureGrad(glyph_atlas, auv, dFdx(uv) * sc, dFdy(uv) * sc).r;
	cov = clamp((cov - 0.08) * 1.5, 0.0, 1.0);

	vec3 pal = mix(PAL_DARK[t], PAL_BRIGHT[t], smoothstep(0.08, 0.85, s));
	if (t == 3) {
		float k = 0.5 + 0.5 * sin(TIME * 0.35 + (w_pos.x + w_pos.z) * 0.8 + h * 3.0);
		pal = mix(vec3(0.55, 0.28, 1.0), vec3(1.0, 0.28, 0.75), k);
	}
	vec3 hue = lit / (max(lit.r, max(lit.g, lit.b)) + 0.001);
	float inten = mix(0.42, 1.0, smoothstep(0.0, 0.75, s));
	vec3 col = pal * mix(vec3(1.0), hue, t >= 2 ? 0.0 : tint_mix) * inten * cov;
	vec3 fill = PAL_DARK[t] * (0.05 + 0.10 * s) * (top ? 1.0 : 0.8);

	vec2 e = (w_pos.xz - slice_params.xy) / slice_params.zw;
	float fade = 1.0 - smoothstep(0.95, 1.25, length(e));
	ALBEDO = (col + fill) * fade;
}
