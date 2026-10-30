// Glyph-surface material (task-031, ported from Spike A). ONE shader for every world surface:
// glyphs live ON the faces (walls, floor, spikes, corruption, items). The glyph grid is derived from
// world space per face (top faces: screen-aligned axes, side faces: surface-aligned) so glyphs follow
// the geometry. Per glyph cell the light is evaluated once at the cell centre; its brightness picks
// the glyph from the type's density ramp (atlas row = surface type, vertex COLOR.r * 8) and the colour
// comes from a per-type gradient tinted by the light colour. No shadows, no screen texture.
// Per vertex: UV = the map cell (for the reveal mask), COLOR.r = type id / 8, NORMAL = face normal.
// Fragment cost: 1 mask fetch, 1 atlas fetch (textureGrad), 1 loop over <= 8 analytic lights.
// Assumes a yaw-only isometric camera; the grid axes are derived from INV_VIEW_MATRIX.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, fog_disabled;

const int MAX_LIGHTS = 8;
const int TYPE_COUNT = 5;
const float ATLAS_COLS = 8.0;            // GlyphAtlasSpec.COLUMNS
const float ATLAS_ROWS = 6.0;            // GlyphAtlasSpec.ROWS
const float TYPE_DIV = 8.0;              // GlyphSurfaceType.TYPE_DIV
const int T_WALL = 0;
const int T_FLOOR = 1;
const int T_CORRUPT = 3;
const float MASK_GAIN = 1.25;            // MapReveal.MASK_BRIGHTNESS_MAX
const float TOP_NORMAL_Y = 0.7;          // |n.y| above this is a top face
const float MIN_SIDE_FACTOR = 0.2;       // guards the side-face width against a face seen edge-on

global uniform sampler2D reveal_mask : filter_nearest;

uniform sampler2D glyph_atlas : filter_linear_mipmap, repeat_disable;
uniform vec4 pal_dark[TYPE_COUNT];       // rgb per surface type
uniform vec4 pal_bright[TYPE_COUNT];
uniform float emit[TYPE_COUNT];
uniform vec3 corrupt_hue_a = vec3(0.55, 0.28, 1.0);
uniform vec3 corrupt_hue_b = vec3(1.0, 0.28, 0.75);
uniform float cell_screen = 0.19;        // glyph cell height on screen, in world units
uniform float cell_aspect = 0.62;        // glyph cell width / height
uniform float glyph_crop = 0.62;         // fraction of the atlas tile width shown per cell
uniform float wall_height = 1.0;
uniform vec4 light_pos[MAX_LIGHTS];      // xyz position, w radius
uniform vec4 light_col[MAX_LIGHTS];      // rgb colour * intensity
uniform int light_count = 1;
uniform float ambient_level = 0.30;
uniform float tint_mix = 0.75;
uniform float memory_dim = 0.35;
uniform float memory_saturation = 0.25;
uniform vec3 glint_color = vec3(0.2, 0.8, 1.0);
uniform vec4 cut_center = vec4(0.0, 0.5, 0.0, 1.1);   // xyz view-ray point (the player), w radius
uniform vec2 cut_params = vec2(0.6, 0.15);            // x soft edge width, y margin towards the camera

varying flat vec3 w_nrm;
varying flat float v_type;
varying flat vec2 v_cell;
varying flat vec3 v_axu;
varying flat vec3 v_axv;
varying flat vec2 v_cellsize;            // glyph cell width / height in world units along v_axu / v_axv
varying vec3 w_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize(mat3(MODEL_MATRIX) * NORMAL);
	w_nrm = n;
	v_type = COLOR.r;
	v_cell = UV;
	vec3 cam_right = INV_VIEW_MATRIX[0].xyz;
	vec3 to_cam = INV_VIEW_MATRIX[2].xyz;
	if (abs(n.y) > TOP_NORMAL_Y) {
		v_axu = normalize(vec3(cam_right.x, 0.0, cam_right.z));
		v_axv = normalize(vec3(to_cam.x, 0.0, to_cam.z));
		v_cellsize = vec2(cell_screen * cell_aspect, cell_screen / max(to_cam.y, MIN_SIDE_FACTOR));
	} else {
		vec3 nh = normalize(vec3(n.x, 0.0, n.z));
		v_axu = normalize(cross(-nh, vec3(0.0, 1.0, 0.0)));
		v_axv = vec3(0.0, -1.0, 0.0);
		float horiz = max(abs(dot(v_axu, cam_right)), MIN_SIDE_FACTOR);
		float vert = max(sqrt(max(1.0 - to_cam.y * to_cam.y, 0.0)), MIN_SIDE_FACTOR);
		v_cellsize = vec2(cell_screen * cell_aspect / horiz, cell_screen / vert);
	}
}

void fragment() {
	// Reveal: hidden cells draw nothing. r = brightness (with overshoot), g = seen fraction, b = glint, a = floor shown.
	vec4 m = texelFetch(reveal_mask, ivec2(v_cell + 0.5), 0);
	int t = int(v_type * TYPE_DIV + 0.5);
	float vis = m.r * MASK_GAIN;
	if (t == T_FLOOR) {
		vis *= m.a;
	}
	if (vis < 0.004) {
		discard;
	}

	// Cut-away: surfaces between the camera and the player never hide the player.
	if (t != T_FLOOR) {
		vec3 to_cam = INV_VIEW_MATRIX[2].xyz;
		vec3 d = w_pos - cut_center.xyz;
		float along = dot(d, to_cam);
		if (along > cut_params.y) {
			float pd = length(d - to_cam * along);
			float keep = smoothstep(cut_center.w, cut_center.w + cut_params.x, pd);
			float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
			if (ign >= keep) {
				discard;
			}
		}
	}

	vec3 n = w_nrm;
	bool top = abs(n.y) > TOP_NORMAL_Y;
	vec3 axu = v_axu;
	vec3 axv = v_axv;
	vec2 uv = vec2(dot(w_pos, axu) / v_cellsize.x, dot(w_pos, axv) / v_cellsize.y);
	vec2 cell = floor(uv);
	vec2 loc = uv - cell;
	vec3 pc = w_pos + axu * ((cell.x + 0.5 - uv.x) * v_cellsize.x) + axv * ((cell.y + 0.5 - uv.y) * v_cellsize.y);

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
	float b = max(lit.r, max(lit.g, lit.b)) + emit[t] * (0.8 + 1.5 * pulse) + (h - 0.5) * 0.10 + pulse;
	if (!top && t == T_WALL) {
		b += smoothstep(wall_height - 0.12, wall_height, w_pos.y) * 0.22;   // rim along wall tops
	}
	b *= min(vis, 1.0);
	float s = clamp(b, 0.0, 0.999);
	float idx = min(1.0 + floor(pow(s, 0.65) * (ATLAS_COLS - 1.0)), ATLAS_COLS - 1.0);

	vec2 auv = vec2((idx + 0.5 + (loc.x - 0.5) * glyph_crop) / ATLAS_COLS, (float(t) + 0.03 + loc.y * 0.94) / ATLAS_ROWS);
	vec2 sc = vec2(glyph_crop / ATLAS_COLS, 0.94 / ATLAS_ROWS);
	float cov = textureGrad(glyph_atlas, auv, dFdx(uv) * sc, dFdy(uv) * sc).r;
	cov = clamp((cov - 0.08) * 1.5, 0.0, 1.0);

	vec3 pal = mix(pal_dark[t].rgb, pal_bright[t].rgb, smoothstep(0.08, 0.85, s));
	if (t == T_CORRUPT) {
		float k = 0.5 + 0.5 * sin(TIME * 0.35 + (w_pos.x + w_pos.z) * 0.8 + h * 3.0);
		pal = mix(corrupt_hue_a, corrupt_hue_b, k);
	}
	vec3 hue = lit / (max(lit.r, max(lit.g, lit.b)) + 0.001);
	float inten = mix(0.42, 1.0, smoothstep(0.0, 0.75, s));
	vec3 col = pal * mix(vec3(1.0), hue, t >= 2 ? 0.0 : tint_mix) * inten * cov;
	vec3 fill = pal_dark[t].rgb * (0.05 + 0.10 * s) * (top ? 1.0 : 0.8);
	vec3 c = col + fill;

	// Memory: remembered cells (g = 0) are dim and desaturated, they turn live as g grows.
	float seen = m.g;
	float grey = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(vec3(grey), c, mix(memory_saturation, 1.0, seen)) * mix(memory_dim, 1.0, seen);
	c += glint_color * m.b * cov;
	ALBEDO = c * vis;
}
