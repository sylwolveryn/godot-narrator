// The in-world menu (task-018): ONE MultiMesh, ONE draw call. Every glyph of the menu (letters, markers, frame) is a
// camera-facing quad that starts as a glyph of the floor or the walls around the player, flies to its place in the
// framed list (Spike B moment 2: stagger, eased flight with overshoot, spin, scale pop, a glyph that flips mid-flight)
// and flies back when the menu closes. The whole flight is evaluated here from per-instance data and a few uniforms
// (open_t, close_t, the selection); the CPU writes the instance buffer once when the menu opens and nothing per glyph
// per frame. The selected item glows warm; the highlight moves with the `selected` / `select_t` uniforms.
//
// Instance data (the transform floats are reused as raw data; the node sits at the origin):
//   MODEL_MATRIX[0].xyz = (end offset x, end offset y, half size)     end: offset from the menu centre on the camera plane
//   MODEL_MATRIX[1].xyz = start offset from `anchor` in world space   start: the floor / wall glyph it was borrowed from
//   MODEL_MATRIX[2].xyz = (delay, duration, spin turns)
//   MODEL_MATRIX[3].xyz = (glyph slot at start, glyph slot at end, seed 0..1)
//   COLOR = colour at the end; INSTANCE_CUSTOM = (item index or -1, kind, arc height, unused)
//   kind: 0 glyph from the floor, 1 glyph from a wall, 2 marker (like 0, only shown on the selected item), 3 panel
//   (the dark backing: half extents in MODEL_MATRIX[3].xy, centre offset in MODEL_MATRIX[0].xy).
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, skip_vertex_transform;

const float HALF_TURN = 3.14159265;
const float TWO_PI = 6.2831853;
const float HIDDEN_BELOW = 0.003;
const float PANEL_SOFT = 0.6;
const vec2 OUTLINE_DIRS[4] = vec2[4](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));

uniform sampler2D glyph_atlas : filter_linear, repeat_disable;
uniform vec2 atlas_grid = vec2(4.0, 4.0);
uniform float glyph_fill = 0.8;
uniform vec4 outline_color : source_color = vec4(0.01, 0.005, 0.03, 1.0);
uniform float outline_width = 0.08;

uniform vec3 anchor = vec3(0.0);          // world position the borrowed glyphs are measured from (the player's feet)
uniform vec3 menu_centre = vec3(0.0);     // world position of the menu centre
uniform float open_t = 1000.0;            // seconds since the menu opened (frozen when it closes)
uniform float close_t = -1.0;             // seconds since the menu closed (< 0 = open)
uniform float return_dur = 0.65;
uniform float return_jitter = 0.4;
uniform float selected = 0.0;
uniform float prev_selected = 0.0;
uniform float select_t = 1000.0;
uniform float select_dur = 0.18;
uniform float select_swell = 0.12;
uniform vec3 select_color = vec3(1.0, 0.93, 0.62);
uniform vec3 glow_color = vec3(1.0, 0.62, 0.22);
uniform float glow_strength = 0.8;
uniform vec3 floor_color = vec3(0.36, 0.4, 0.62);
uniform vec3 wall_color = vec3(0.45, 0.58, 0.9);
uniform float start_ratio = 0.45;
uniform float pop = 0.4;
uniform float flash = 0.15;
uniform float overshoot = 1.2;
uniform float bob_amount = 0.02;
uniform float bob_speed = 2.0;
uniform float panel_alpha = 0.55;
uniform vec3 panel_color = vec3(0.01, 0.01, 0.03);

varying vec2 q;
varying vec4 tint;
varying flat float slot;
varying flat float glow;
varying flat float panel;
varying flat vec2 panel_half;

float hash11(float x) {
	return fract(sin(x * 12.9898 + 4.1414) * 43758.5453);
}

float ease_out_back(float x) {
	float c3 = overshoot + 1.0;
	float y = x - 1.0;
	return 1.0 + c3 * y * y * y + overshoot * y * y;
}

void vertex() {
	vec2 end_p = MODEL_MATRIX[0].xy;
	float size = MODEL_MATRIX[0].z;
	vec3 start_w = MODEL_MATRIX[1].xyz;
	float delay = MODEL_MATRIX[2].x;
	float dur = max(MODEL_MATRIX[2].y, 0.001);
	float spin = MODEL_MATRIX[2].z;
	float g_from = MODEL_MATRIX[3].x;
	float g_to = MODEL_MATRIX[3].y;
	float seed = MODEL_MATRIX[3].z;
	float item = INSTANCE_CUSTOM.x;
	float kind = INSTANCE_CUSTOM.y;
	float arc = INSTANCE_CUSTOM.z;

	// --- flight progress: out on open, the time-reverse of it on close (no jump if closed mid-flight) ---
	float u = clamp((open_t - delay) / dur, 0.0, 1.0);
	if (close_t >= 0.0) {
		float rd = hash11(seed * 5.1) * return_jitter;
		float rdur = max(return_dur * (0.8 + 0.4 * hash11(seed * 9.3)), 0.001);
		u = min(u, 1.0 - clamp((close_t - rd) / rdur, 0.0, 1.0));
	}
	float us = u * u * (3.0 - 2.0 * u);
	float e = ease_out_back(us);
	float hump = sin(HALF_TURN * u);

	vec4 vs = VIEW_MATRIX * vec4(anchor + start_w, 1.0);
	vec4 ve = VIEW_MATRIX * vec4(menu_centre, 1.0);
	ve.xy += end_p;
	float a = seed * TWO_PI;
	vec4 vp = mix(vs, ve, e);
	vp.xy += vec2(cos(a) * 0.4, 1.0) * arc * hump;

	// --- selection highlight ---
	float hl = 0.0;
	if (item >= -0.5) {
		float k = smoothstep(0.0, 1.0, clamp(select_t / max(select_dur, 0.001), 0.0, 1.0));
		hl = (abs(item - selected) < 0.5 ? k : 0.0) + (abs(item - prev_selected) < 0.5 ? 1.0 - k : 0.0);
		hl = clamp(hl, 0.0, 1.0);
	}

	float settle = smoothstep(0.92, 1.0, u);
	vec2 bob = vec2(cos(TIME * bob_speed * 0.7 + seed * 40.0), sin(TIME * bob_speed + seed * 40.0)) * bob_amount * settle;
	vec3 col = COLOR.rgb;
	float alpha = smoothstep(0.0, 0.2, u);
	float s = mix(start_ratio * size, size, us) * (1.0 + pop * hump) * (1.0 + select_swell * hl);
	float ang = spin * TWO_PI * us;
	float glyph = g_to;
	float fx = 1.0;
	panel = 0.0;
	panel_half = vec2(1.0);

	if (kind > 2.5) {
		// The dark backing: grows in place and fades, no flight.
		panel = 1.0;
		panel_half = MODEL_MATRIX[3].xy;
		vp = ve;
		alpha = panel_alpha * smoothstep(0.0, 1.0, u);
		s = 1.0;
		ang = 0.0;
		col = panel_color;
		glow = 0.0;
	} else {
		if (kind > 1.5) {
			alpha *= hl;
			vp.x += sin(TIME * 6.0 + item) * 0.05 * hl * (end_p.x < 0.0 ? 1.0 : -1.0);
		}
		vp.xy += bob;
		if (abs(g_from - g_to) > 0.5) {
			float f = smoothstep(0.2, 0.8, u);
			glyph = f < 0.5 ? g_from : g_to;
			fx = max(abs(cos(HALF_TURN * f)), 0.04);
		}
		vec3 start_col = kind > 0.5 && kind < 1.5 ? wall_color : floor_color;
		col = mix(start_col, mix(col, select_color, hl), smoothstep(0.1, 0.9, u)) + vec3(flash * hump);
		glow = hl * glow_strength * smoothstep(0.7, 1.0, u);
	}
	slot = glyph;
	tint = vec4(col, alpha);

	if (alpha < HIDDEN_BELOW || s < 0.001) {
		POSITION = vec4(0.0, 0.0, 2.0, 1.0);
		q = vec2(0.0);
	} else {
		vec2 qv = VERTEX.xy;
		vec2 corner;
		if (panel > 0.5) {
			corner = qv * panel_half * (0.92 + 0.08 * us);
		} else {
			float cs = cos(ang);
			float sn = sin(ang);
			corner = vec2(cs * qv.x * fx - sn * qv.y, sn * qv.x * fx + cs * qv.y) * s;
		}
		vp.xy += corner;
		POSITION = PROJECTION_MATRIX * vp;
		q = qv;
	}
}

// Coverage of one atlas slot at tile coordinates uv (0..1, y down); 0 outside the tile.
float slot_cov(float idx, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	vec2 tile = vec2(mod(idx + 0.5, atlas_grid.x), floor((idx + 0.5) / atlas_grid.x));
	return texture(glyph_atlas, (floor(tile) + uv) / atlas_grid).a;
}

void fragment() {
	if (panel > 0.5) {
		vec2 inner = vec2(1.0) - vec2(PANEL_SOFT) / panel_half;
		vec2 edge = 1.0 - smoothstep(inner, vec2(1.0), abs(q));
		float pa = tint.a * edge.x * edge.y;
		ALBEDO = tint.rgb * pa;
		ALPHA = pa;
	} else {
		vec2 gp = vec2(q.x, -q.y) * (0.5 / glyph_fill) + 0.5;
		float cov = slot_cov(slot, gp);
		float back = 0.0;
		if (outline_width > 0.0 && gp.x > -0.15 && gp.x < 1.15 && gp.y > -0.15 && gp.y < 1.15) {
			for (int i = 0; i < 4; i++) {
				back = max(back, slot_cov(slot, gp + OUTLINE_DIRS[i] * outline_width));
			}
			back *= outline_color.a;
		}
		vec3 rgb = tint.rgb * cov + outline_color.rgb * back * (1.0 - cov);
		float al = cov + back * (1.0 - cov);
		float halo = glow * pow(clamp(1.0 - length(q), 0.0, 1.0), 1.6);
		ALBEDO = (rgb + glow_color * halo) * tint.a;
		ALPHA = al * tint.a;
	}
}
