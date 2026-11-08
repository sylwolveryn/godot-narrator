// Glyph-surface material (task-031, ported from Spike A). ONE shader for every world surface:
// glyphs live ON the faces (walls, floor, spikes, corruption, items). The glyph grid is derived from
// world space per face (top faces: screen-aligned axes, side faces: surface-aligned) so glyphs follow
// the geometry. Per glyph cell the light is evaluated once at the cell centre; its brightness picks
// the glyph from the type's density ramp (atlas row = surface type, vertex COLOR.r * 8) and the colour
// comes from a per-type gradient tinted by the light colour. No shadows, no screen texture.
// Per vertex: UV = the map cell (for the reveal mask), COLOR.r = type id / 8, NORMAL = face normal,
// COLOR.g = wall edge bits / 16, COLOR.b = 1 on the floor quad under a wall (see WorldMeshBuilder).
//
// Look pass (task-036): wall faces read as carved stone (block seams on a world grid, static per-block variation,
// bright rims where a face meets a free edge, darker wall bases), distance and screen-top darkening for depth, and
// light occlusion from two small per-cell visibility textures computed on the CPU (GlyphLightOcclusion): channel i of
// (light_vis_a, light_vis_b) is the visibility of light slot i, sampled per glyph cell. The floor region of the
// texture (x < map width) is sampled bilinear; the wall region (x > map width) holds, per wall cell, the best
// visibility of its open neighbours and is fetched nearest (wall tops, floor under walls). Wall side faces sample the
// open cell in front of the face, so a light behind a wall does not light the far side.
// Fragment cost: 1 mask fetch, 1 atlas fetch (textureGrad), 1-2 visibility fetches (the 2nd only above 4 lights),
// 1 loop over <= 8 analytic point lights, ~60 extra ALU for the carved look and depth.
// Assumes a yaw-only isometric camera; the grid axes are derived from INV_VIEW_MATRIX.
//
// Layered clarity (task-066, `clarity` 0..1 from the language understanding): floor, hazards, items and pushable objects
// normally each resolve their own glyph grid per face, so where they meet on screen the grids interleave. A share
// `clarity` of the glyph cells (picked by a per-cell hash, so every percent tones it down) is drawn "layered" instead:
// the fragment is projected along the view ray to the floor, so every fragment of one SCREEN glyph cell (floor or any
// face of a hazard / item / object box) lands in the same floor-grid cell; the cell's owner is found by walking the
// view ray of the cell centre through `layer_map` (per map cell: order, type, box height and half extent) and taking
// the highest order hit (floor 0 < hazards 1 < items / objects 2). The whole cell then draws ONE glyph of its owner,
// lit at the hit point, so no glyph is ever split between two surfaces. clarity 0 skips all of it (the old look).
// Cost when on: 1 layer_map fetch per floor/hazard cell, plus <= LAYER_SAMPLES_MAX fetches and ~20 ALU each only on
// cells within layer reach of a layered object (layer_map.a); walls are never layered.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, fog_disabled;

const int MAX_LIGHTS = 8;
const int TYPE_COUNT = 5;
const float ATLAS_COLS = 8.0;            // GlyphAtlasSpec.COLUMNS
const float ATLAS_ROWS = 6.0;            // GlyphAtlasSpec.ROWS
const float TYPE_DIV = 8.0;              // GlyphSurfaceType.TYPE_DIV
const float EDGE_DIV = 16.0;             // WorldMeshBuilder.EDGE_DIV
const int T_WALL = 0;
const int T_FLOOR = 1;
const int T_CORRUPT = 3;
const int ANIM_COLS = 8;                 // GlyphAnimConfig.max_chars
const int ANIM_PAL = 6;                  // GlyphAnimConfig.max_palette
const float MASK_GAIN = 1.25;            // MapReveal.MASK_BRIGHTNESS_MAX
const float TOP_NORMAL_Y = 0.7;          // |n.y| above this is a top face
const float MIN_SIDE_FACTOR = 0.2;       // guards the side-face width against a face seen edge-on
const int LAYER_SAMPLES_MAX = 6;         // GlyphWorldConfig.layer_ray_samples upper bound
const float LAYER_CODE = 255.0;          // layer_map.r = (order * LAYER_TYPES + type) / LAYER_CODE
const int LAYER_TYPES = 8;
const vec2 LAYER_SALT = vec2(41.7, 13.3); // hash salt of the per-cell layered pick
const float FLOOR_HASH_N = 2.9;          // dot(up, (1.7, 2.9, 3.3)): the old floor glyph hash, kept for layered cells
const float RAY_EPS = 0.0001;
const int MAX_WAVES = 8;                 // TeleportView.MAX_WAVES
const float WAVE_REACH = 2.5;            // a wave band is skipped beyond this many band widths


global uniform sampler2D reveal_mask : filter_nearest;

uniform sampler2D light_vis_a : filter_linear, repeat_disable;   // light slots 0..3 in r,g,b,a
uniform sampler2D light_vis_b : filter_linear, repeat_disable;   // light slots 4..7
uniform vec4 vis_params = vec4(40.0, 23.0, 1.0, 0.0);            // xy map size in cells, z world units per cell, w 1 = occlusion on
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
uniform vec3 memory_tint = vec3(0.62, 0.8, 1.15);   // colour multiplier of remembered cells (cool)
uniform float memory_density = 0.6;      // remembered cells use this fraction of their light for the glyph density (sparser)
uniform float memory_dropout = 0.35;     // share of glyphs missing on remembered cells
uniform float memory_floor = 0.3;        // brightness every remembered glyph cell has at least (keeps memory readable in the dark)
uniform float memory_emit = 0.25;        // share of the self-lit glow kept on remembered cells
uniform float reveal_spread = 0.8;       // how far apart (in reveal progress) the glyphs of a cell materialise, 0 = all at once
uniform vec3 glint_color = vec3(0.2, 0.8, 1.0);
uniform float light_falloff_sharp = 0.6; // 0 = linear light falloff, 1 = quadratic (light concentrates near the source)
// carved stone
uniform vec2 wall_block = vec2(0.66, 0.5);  // block width / course height of the wall masonry, world units
uniform float floor_tile = 0.5;             // flagstone size of the floor
uniform float seam_width = 0.07;            // seams are this wide (world units, resolved per glyph cell)
uniform float seam_dim = 0.55;              // brightness kept on a seam
uniform float block_variation = 0.28;       // static per-block brightness variation
uniform float edge_width = 0.11;            // rim width on wall tops (world units)
uniform float edge_gain = 1.1;              // rim cells gain this fraction of the light they catch
uniform float edge_ambient = 0.10;          // light every rim catches even in the dark
uniform float wall_base_dark = 0.6;         // brightness kept at the foot of a wall
uniform float wall_ao_height = 0.7;         // height over which the foot darkening fades out
uniform float wall_top_ambient = 0.7;       // ambient on wall tops (they are dark stone, the rims carry the outline)
// depth
uniform float depth_near = 3.0;             // ambient starts fading at this distance from the player light
uniform float depth_far = 9.0;
uniform float depth_ambient_min = 0.35;     // ambient kept at depth_far and beyond
uniform float fog_strength = 0.35;          // darkening towards the top of the screen
uniform float fog_start = 0.3;              // fraction of the screen height (from the bottom) where the fog begins
// small pushable objects (task-019): free-standing wall-type blocks drawn as a MultiMesh; COLOR.b = 0.5, the cell is the one the instance origin is in
uniform vec2 object_params = vec2(0.5, 0.31);   // x block height, y half edge length (world units)
uniform vec4 lift_zone = vec4(0.0, 0.0, 1.0, 0.0);   // in-world menu (task-018): xz centre, radius, dim amount while its glyphs are away
uniform vec4 storm_zone = vec4(0.0, 0.0, 1.0, 0.0);  // glyph storm (task-030): same, while the storm's glyphs are away
// DB-driven glyph animation (task-054, GlyphAnimView). Per surface type:
uniform sampler2D anim_atlas : filter_linear, repeat_disable;   // ANIM_COLS characters per row, one row per type
uniform vec4 anim_params[TYPE_COUNT];    // x share animating at the player, y share at radius+, z radius (world), w 1 = on
uniform vec4 anim_speed[TYPE_COUNT];     // x character changes / s, y palette cycles / s, z character count, w palette size
uniform vec4 anim_palette[30];           // TYPE_COUNT * ANIM_PAL colours
uniform vec2 anim_brightness = vec2(0.55, 1.25);   // brightness of an animated glyph unlit / fully lit
// Layered clarity (task-066, GlyphWorldView): see the header.
uniform float clarity = 0.0;
uniform sampler2D layer_map : filter_nearest, repeat_disable;   // r order/type code, g height / layer_params.x, b half extent * 2 (cell fraction), a 1 = near a layered box
uniform vec2 layer_params = vec2(1.0, 4.0);   // x ray height (world units, also the g scale), y ray samples

// Colour waves (task-068, TeleportView): up to MAX_WAVES expanding rings that add vibrant colour and glyph density to the
// floor and walls they pass. Per glyph cell (cell centre pc), so the ring steps in ASCII cells. wave_count 0 = no cost.
uniform int wave_count = 0;
uniform vec4 wave_geo[MAX_WAVES];        // xz centre, z ring radius, w band half width (world units)
uniform vec4 wave_col[MAX_WAVES];        // rgb colour, a strength
uniform vec4 wave_style = vec4(0.12, 0.6, 0.55, 0.6);   // x rainbow phase per world unit, y per second, z rainbow mix, w glyph density gain

varying flat vec3 w_nrm;
varying flat float v_type;
varying flat float v_flags;              // COLOR.g: edge bits
varying flat float v_under;              // COLOR.b: floor quad under a wall
varying flat vec2 v_cell;
varying flat vec3 v_axu;
varying flat vec3 v_axv;
varying flat vec3 v_origin;              // model origin (the centre of a small object)
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
	v_flags = COLOR.g;
	v_under = COLOR.b;
	v_origin = MODEL_MATRIX[3].xyz;
	v_cell = UV;
	if (COLOR.b > 0.25 && COLOR.b < 0.75) {
		v_cell = floor(v_origin.xz / vis_params.z);   // small object: the cell its centre is in
	}
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
	int t = int(v_type * TYPE_DIV + 0.5);
	float cs = vis_params.z;
	vec3 n = w_nrm;
	bool top = abs(n.y) > TOP_NORMAL_Y;
	vec2 uv;
	vec2 cell;
	vec3 pc;
	vec4 m;
	bool cl = false;                       // layered cell (see the header)
	// Layered clarity: floor (not under a wall), hazards, items and free-standing objects.
	if (clarity > 0.0 && (t >= 2 || (t == T_FLOOR && v_under < 0.25) || (t == T_WALL && v_under > 0.25 && v_under < 0.75))) {
		vec3 cr = INV_VIEW_MATRIX[0].xyz;
		vec3 tc = INV_VIEW_MATRIX[2].xyz;
		float ty = max(tc.y, MIN_SIDE_FACTOR);
		vec3 gu = normalize(vec3(cr.x, 0.0, cr.z));
		vec3 gv = normalize(vec3(tc.x, 0.0, tc.z));
		vec2 gcs = vec2(cell_screen * cell_aspect, cell_screen / ty);
		vec3 p0 = w_pos - tc * (w_pos.y / ty);                 // the floor point on this fragment's view ray
		vec2 guv = vec2(dot(p0, gu) / gcs.x, dot(p0, gv) / gcs.y);
		vec2 gcell = floor(guv);
		if (hash12(gcell + LAYER_SALT) < clarity) {
			cl = true;
			uv = guv;
			cell = gcell;
			vec3 gc = p0 + gu * ((gcell.x + 0.5 - guv.x) * gcs.x) + gv * ((gcell.y + 0.5 - guv.y) * gcs.y);
			ivec2 lim = ivec2(vis_params.xy + 0.5) - 1;
			ivec2 c0 = clamp(ivec2(floor(gc.xz / cs)), ivec2(0), lim);
			vec4 l0 = texelFetch(layer_map, c0, 0);
			int owner = 0;                     // order * LAYER_TYPES + type of the owner, 0 = floor
			float best_h = -1.0;
			float hit_h = 0.0;
			ivec2 hit_c = c0;
			vec2 dir = tc.xz / ty;             // floor offset per unit of height along the ray towards the camera
			if (l0.a > 0.5) {
				vec2 ds = vec2(abs(dir.x) < RAY_EPS ? RAY_EPS : dir.x, abs(dir.y) < RAY_EPS ? RAY_EPS : dir.y);
				int ns = int(layer_params.y + 0.5);
				float hstep = layer_params.x / max(layer_params.y - 1.0, 1.0);
				for (int k = 0; k < LAYER_SAMPLES_MAX; k++) {
					if (k >= ns) {
						break;
					}
					ivec2 ci = clamp(ivec2(floor((gc.xz + dir * (hstep * float(k))) / cs)), ivec2(0), lim);
					vec4 l = k == 0 ? l0 : texelFetch(layer_map, ci, 0);
					int code = int(l.r * LAYER_CODE + 0.5);
					if (code == 0) {
						continue;
					}
					// Heights at which the ray is inside the cell's box (slab test), clipped to 0..box height.
					vec2 ctr = (vec2(ci) + 0.5) * cs - gc.xz;
					float hf = l.b * 0.5 * cs;
					vec2 t1 = (ctr - hf) / ds;
					vec2 t2 = (ctr + hf) / ds;
					vec2 tn = min(t1, t2);
					vec2 tf = max(t1, t2);
					float h0 = max(max(tn.x, tn.y), 0.0);
					float h1 = min(min(tf.x, tf.y), l.g * layer_params.x);
					if (h0 <= h1 && (code / LAYER_TYPES > owner / LAYER_TYPES || (code / LAYER_TYPES == owner / LAYER_TYPES && h1 >= best_h))) {
						owner = code;
						best_h = h1;
						hit_h = (h0 + h1) * 0.5;
						hit_c = ci;
					}
				}
			}
			n = vec3(0.0, 1.0, 0.0);
			top = true;
			if (owner > 0) {
				m = texelFetch(reveal_mask, hit_c, 0);
				if (m.r * MASK_GAIN < 0.004) {
					owner = 0;                 // a hidden box does not own its cells
				}
			}
			if (owner > 0) {
				t = owner - (owner / LAYER_TYPES) * LAYER_TYPES;
				pc = vec3(gc.x + dir.x * hit_h, hit_h, gc.z + dir.y * hit_h);
			} else {
				t = T_FLOOR;
				pc = gc;
				m = texelFetch(reveal_mask, c0, 0);
			}
		}
	}
	if (!cl) {
		m = texelFetch(reveal_mask, ivec2(v_cell + 0.5), 0);
	}
	// Reveal: hidden cells draw nothing. r = brightness (with overshoot), g = seen fraction, b = glint, a = floor shown.
	float vis = m.r * MASK_GAIN;
	if (t == T_FLOOR) {
		vis *= m.a;
	}
	if (vis < 0.004) {
		discard;
	}

	vec3 axu = v_axu;
	vec3 axv = v_axv;
	float h;
	if (cl) {
		h = hash12(cell + vec2(float(t) * 7.31, FLOOR_HASH_N));
	} else {
		uv = vec2(dot(w_pos, axu) / v_cellsize.x, dot(w_pos, axv) / v_cellsize.y);
		cell = floor(uv);
		pc = w_pos + axu * ((cell.x + 0.5 - uv.x) * v_cellsize.x) + axv * ((cell.y + 0.5 - uv.y) * v_cellsize.y);
		h = hash12(cell + vec2(float(t) * 7.31, dot(n, vec3(1.7, 2.9, 3.3)) + floor(dot(w_pos, n) * 4.0)));
	}
	vec2 loc = uv - cell;
	vec3 hp = cl ? pc : w_pos;             // per-pixel position for the colour waves (per cell when layered)

	// Light visibility per slot (occlusion), see the header.
	float vis_l[8] = float[8](1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0);
	if (vis_params.w > 0.5) {
		vec4 va;
		vec4 vb = vec4(1.0);
		bool wall_cell = !cl && v_under < 0.25;       // false for a free-standing small object
		if ((t == T_WALL && top && wall_cell) || (t == T_FLOOR && !cl && v_under > 0.5)) {
			ivec2 wc = ivec2(v_cell + 0.5) + ivec2(int(vis_params.x + 0.5) + 1, 0);
			va = texelFetch(light_vis_a, wc, 0);
			if (light_count > 4) {
				vb = texelFetch(light_vis_b, wc, 0);
			}
		} else {
			vec2 vp = pc.xz / cs;
			if (t == T_WALL && wall_cell) {
				vp += n.xz * 0.5;
			}
			vec2 vuv = vp / vec2(2.0 * vis_params.x + 1.0, vis_params.y);
			va = texture(light_vis_a, vuv);
			if (light_count > 4) {
				vb = texture(light_vis_b, vuv);
			}
		}
		vis_l = float[8](va.r, va.g, va.b, va.a, vb.r, vb.g, vb.b, vb.a);
	}

	// light at the cell centre
	float face_amb = top ? (t == T_WALL ? wall_top_ambient : 1.0) : (n.z > 0.5 ? 0.7 : 0.45);
	float depth_k = smoothstep(depth_near, depth_far, length(pc.xz - light_pos[0].xz));
	vec3 lit = vec3(0.55, 0.65, 1.0) * ambient_level * face_amb * mix(1.0, depth_ambient_min, depth_k);
	vec3 lights = vec3(0.0);
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= light_count) {
			break;
		}
		vec3 L = light_pos[i].xyz - pc;
		float d = length(L);
		float att = clamp(1.0 - d / light_pos[i].w, 0.0, 1.0);
		att = mix(att, att * att, light_falloff_sharp);
		float ndl = 0.45 + 0.55 * smoothstep(-0.15, 0.65, dot(n, L / max(d, 0.001)));
		lights += light_col[i].rgb * (att * ndl * vis_l[i]);
	}
	lit += lights;
	float lum_l = max(lights.r, max(lights.g, lights.b));

	// Carved stone: masonry blocks on a world grid (running bond on walls), seams, static per-block variation,
	// bright rims on free edges, darker wall feet.
	float stone = 1.0;
	float edge = 0.0;
	if (t == T_WALL || t == T_FLOOR) {
		vec2 bs = wall_block;
		float along = top ? pc.x : dot(pc, axu);
		float course_pos = top ? pc.z : pc.y;
		if (t == T_FLOOR) {
			bs = vec2(floor_tile);
		} else if (top) {
			bs = vec2(wall_block.x);
		}
		float course = floor(course_pos / bs.y);
		float su = along / bs.x + 0.5 * mod(course, 2.0);
		vec2 bf = vec2(fract(su) * bs.x, fract(course_pos / bs.y) * bs.y);
		float seam = (bf.x < seam_width || bf.y < seam_width) ? 1.0 : 0.0;
		float bvar = hash12(vec2(floor(su), course) + vec2(float(t) * 3.7, dot(abs(n), vec3(1.3, 2.1, 4.7))));
		stone = (1.0 + (bvar - 0.5) * 2.0 * block_variation) * mix(1.0, seam_dim, seam);
		if (t == T_WALL && !cl) {
			int fl = int(v_flags * EDGE_DIV + 0.5);
			bool free_stand = v_under > 0.25;
			if (top && free_stand) {
				vec2 od = object_params.y - abs(pc.xz - v_origin.xz);
				edge = step(min(od.x, od.y), edge_width);
			} else if (top) {
				vec2 lo = pc.xz - v_cell * cs;
				float e = float(fl & 1) * step(lo.x, edge_width);
				e = max(e, float((fl >> 1) & 1) * step(cs - lo.x, edge_width));
				e = max(e, float((fl >> 2) & 1) * step(lo.y, edge_width));
				e = max(e, float((fl >> 3) & 1) * step(cs - lo.y, edge_width));
				edge = e;
			} else {
				float la = abs(n.x) > 0.5 ? pc.z - v_cell.y * cs : pc.x - v_cell.x * cs;
				float top_y = free_stand ? object_params.x : wall_height;
				float e = step((top_y - pc.y) / v_cellsize.y, 0.5);
				e = max(e, float(fl & 1) * step(la / v_cellsize.x, 0.5));
				e = max(e, float((fl >> 1) & 1) * step((cs - la) / v_cellsize.x, 0.5));
				edge = e;
				stone *= mix(wall_base_dark, 1.0, smoothstep(0.0, wall_ao_height, pc.y * wall_height / top_y));
			}
		}
	}

	// Memory (g = 0 remembered, 1 seen): sparser, dimmer glyphs; reveal (r < 1): glyphs materialise one by one.
	float seen = m.g;
	float mem = 1.0 - seen;
	float pulse = 0.04 * sin(TIME * 0.55 + h * 6.2832);
	float b = max(lit.r, max(lit.g, lit.b)) * stone + emit[t] * mix(memory_emit, 1.0, seen) * (0.8 + 1.5 * pulse) + (h - 0.5) * 0.10 + pulse;
	b += edge * edge_gain * (lum_l + edge_ambient);
	b *= min(vis, 1.0) * mix(1.0, memory_density, mem);
	b = max(b, memory_floor * mem * (t == T_FLOOR ? 0.8 : 1.0));
	vec3 wave_c = vec3(0.0);
	if (wave_count > 0) {
		for (int i = 0; i < MAX_WAVES; i++) {
			if (i >= wave_count) {
				break;
			}
			vec4 wg = wave_geo[i];
			float wd = distance(pc.xz, wg.xy);
			float wx = (wd - wg.z) / wg.w;
			if (abs(wx) > WAVE_REACH) {
				continue;
			}
			float wk = exp(-wx * wx) * wave_col[i].a;
			vec3 rainbow = 0.5 + 0.5 * cos(TAU * (wd * wave_style.x - TIME * wave_style.y + float(i) * 0.37 + vec3(0.0, 0.33, 0.67)));
			wave_c += mix(wave_col[i].rgb, rainbow, wave_style.z) * wk;
		}
		b += max(wave_c.r, max(wave_c.g, wave_c.b)) * wave_style.w;
	}
	if (lift_zone.w > 0.0) {
		b *= 1.0 - lift_zone.w * (1.0 - smoothstep(lift_zone.z * 0.4, lift_zone.z, distance(hp.xz, lift_zone.xy)));
	}
	if (storm_zone.w > 0.0) {
		b *= 1.0 - storm_zone.w * (1.0 - smoothstep(storm_zone.z * 0.4, storm_zone.z, distance(hp.xz, storm_zone.xy)));
	}
	float s = clamp(b, 0.0, 0.999);
	float idx = min(1.0 + floor(pow(s, 0.65) * (ATLAS_COLS - 1.0)), ATLAS_COLS - 1.0);

	vec2 auv = vec2((idx + 0.5 + (loc.x - 0.5) * glyph_crop) / ATLAS_COLS, (float(t) + 0.03 + loc.y * 0.94) / ATLAS_ROWS);
	vec2 sc = vec2(glyph_crop / ATLAS_COLS, 0.94 / ATLAS_ROWS);
	float cov = textureGrad(glyph_atlas, auv, dFdx(uv) * sc, dFdy(uv) * sc).r;
	cov = clamp((cov - 0.08) * 1.5, 0.0, 1.0);
	float hg = hash12(cell * 1.37 + vec2(float(t) * 5.13, 11.9));
	float grow = clamp(min(vis, 1.0) * (1.0 + reveal_spread) - hg * reveal_spread, 0.0, 1.0);
	cov *= grow * step(memory_dropout * mem, hg);

	vec3 pal = mix(pal_dark[t].rgb, pal_bright[t].rgb, smoothstep(0.08, 0.85, s));
	if (t == T_CORRUPT) {
		float k = 0.5 + 0.5 * sin(TIME * 0.35 + (hp.x + hp.z) * 0.8 + h * 3.0);
		pal = mix(corrupt_hue_a, corrupt_hue_b, k);
	}
	vec3 hue = lit / (max(lit.r, max(lit.g, lit.b)) + 0.001);
	float inten = mix(0.42, 1.0, smoothstep(0.0, 0.75, s));
	vec3 col = pal * mix(vec3(1.0), hue, t >= 2 ? 0.0 : tint_mix * m.g) * inten * cov;
	// DB-driven glyph animation: near the player more (or fewer, per the table) glyphs of a live cell swap to cycling
	// characters whose colour blends through the surface's palette. Decided per glyph cell and per tick.
	vec4 ap = anim_params[t];
	if (ap.w > 0.5 && seen > 0.5) {
		float prox = 1.0 - smoothstep(0.0, max(ap.z, 0.001), length(pc.xz - light_pos[0].xz));
		vec4 sp = anim_speed[t];
		float tick = floor(TIME * sp.x + h * 17.0);
		if (hash12(cell * 1.91 + vec2(tick * 0.371, float(t) * 2.3)) < mix(ap.y, ap.x, prox)) {
			float ci = min(floor(hash12(cell * 0.73 + vec2(tick * 1.13, 5.9)) * sp.z), sp.z - 1.0);
			vec2 a_uv = vec2((ci + 0.5 + (loc.x - 0.5) * glyph_crop) / float(ANIM_COLS), (float(t) + 0.03 + loc.y * 0.94) / float(TYPE_COUNT));
			float acov = clamp((textureLod(anim_atlas, a_uv, 0.0).r - 0.08) * 1.5, 0.0, 1.0) * grow;
			float pp = fract(TIME * sp.y + h) * sp.w;
			int i0 = min(int(pp), ANIM_PAL - 1);
			int i1 = int(mod(float(i0 + 1), max(sp.w, 1.0)));
			vec3 acol = mix(anim_palette[t * ANIM_PAL + i0].rgb, anim_palette[t * ANIM_PAL + i1].rgb, fract(pp));
			col = acol * mix(anim_brightness.x, anim_brightness.y, s) * acov;
			cov = acov;
		}
	}
	vec3 fill = pal_dark[t].rgb * (0.05 + 0.10 * s) * (top ? 1.0 : 0.8) * grow;
	vec3 c = col + fill;

	// Memory: remembered cells (g = 0) are dim and desaturated, they turn live as g grows.
	float grey = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(vec3(grey), c, mix(memory_saturation, 1.0, seen)) * mix(memory_dim, 1.0, seen) * mix(memory_tint, vec3(1.0), seen);
	c += glint_color * m.b * cov;
	// Colour waves: the glyphs in a band take the wave's (saturated) hue and brighten; a faint fill lights the cell.
	float wave_k = max(wave_c.r, max(wave_c.g, wave_c.b));
	if (wave_k > 0.0) {
		vec3 wave_hue = wave_c / wave_k;
		wave_hue *= wave_hue;              // more saturated
		float wave_a = min(wave_k, 1.0);
		c = mix(c, wave_hue * cov * min(0.8 + 0.3 * wave_k, 1.3), wave_a) + wave_hue * (0.1 * wave_a * grow);
	}
	// Depth fog: the far (upper) part of the screen sinks into the dark.
	float screen_top = 1.0 - FRAGCOORD.y / VIEWPORT_SIZE.y;
	c *= 1.0 - fog_strength * smoothstep(fog_start, 1.0, screen_top);
	ALBEDO = c * vis;
}
