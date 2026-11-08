// The body of the grown multi-glyph entity (task-017): ONE MultiMesh, ONE draw call, every glyph a camera-facing quad.
// Everything that moves is evaluated here from per-instance data and a few uniforms, so the CPU writes nothing per
// frame per glyph: the grow moment (Spike B style: eased flight with stagger and overshoot, spin, scale pop, a glyph
// that flips mid-flight), the idle bob, the lag when the entity walks, the fold back into the single glyph, the
// erosion (glyphs blend into substitutes, take the hazard tint, drift off and fade in turn) and the death burst.
// The heart (the identity glyph) is NOT drawn here: PlayerGlyphView draws it.
//
// Instance data (the transform floats are reused as raw data; the node sits at the origin):
//   MODEL_MATRIX[0].xyz = (end offset x, end offset y, half size)     offsets on the camera plane, world units
//   MODEL_MATRIX[1].xyz = (start offset x, start offset y, delay)
//   MODEL_MATRIX[2].xyz = (duration, spin turns, arc height)
//   MODEL_MATRIX[3].xyz = (glyph slot at start, glyph slot at end, seed 0..1)
//   COLOR = glyph colour; INSTANCE_CUSTOM.x = size at the start / size at the end.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, skip_vertex_transform;

const float HALF_TURN = 3.14159265;
const float TWO_PI = 6.2831853;
const float HIDDEN_BELOW = 0.003;
const vec2 OUTLINE_DIRS[4] = vec2[4](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));

uniform sampler2D glyph_atlas : filter_linear, repeat_disable;
uniform vec2 atlas_grid = vec2(4.0, 4.0);
uniform float glyph_fill = 0.8;
uniform vec4 outline_color : source_color = vec4(0.015, 0.01, 0.03, 0.9);
uniform float outline_width = 0.035;

uniform vec3 centre = vec3(0.0);          // world position of the heart
uniform float grow_t = 1000.0;            // seconds since the grow started
uniform float fold_t = -1.0;              // seconds since the fold started (< 0 = not folding)
uniform float fold_dur = 0.6;
uniform float death_t = -1.0;             // seconds since the burst (< 0 = alive)
uniform float death_life = 1.0;
uniform float death_dist = 2.6;
uniform float level = 0.0;                // erosion 0..1
uniform vec3 erosion_tint = vec3(0.85, 0.25, 0.95);
uniform float tint_strength = 0.85;
uniform float blend_max = 0.85;
uniform float fade_min_alpha = 0.6;
uniform float shed_share = 0.7;
uniform float shed_period = 3.2;
uniform float shed_distance = 1.3;
uniform float shed_min_alpha = 0.15;
uniform float sub_period = 2.4;
uniform float sub_first = 0.0;           // first substitute slot
uniform float sub_count = 1.0;
uniform vec2 trail = vec2(0.0);           // smoothed velocity on the camera plane x trail_lag
uniform float bob_amount = 0.035;
uniform float bob_speed = 2.3;
uniform float pop = 0.45;
uniform float flash = 0.18;
uniform float overshoot = 1.35;
uniform vec3 gather_color = vec3(0.45, 0.62, 0.78);
uniform float opacity = 1.0;              // 0 hides the whole body
// Understanding look (task-066, same rule as glyph_actor): 1 = edge band only; colour grade (1, 1 = plain).
uniform float hollow = 0.0;
uniform float face_saturation = 1.0;
uniform float face_brightness = 1.0;

varying vec2 q;
varying vec4 tint;
varying flat vec4 slots;                  // base glyph, substitute A, substitute B, A->B crossfade
varying flat float blend;
varying flat float flip_x;

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
	vec2 start_p = MODEL_MATRIX[1].xy;
	float delay = MODEL_MATRIX[1].z;
	float dur = max(MODEL_MATRIX[2].x, 0.001);
	float spin = MODEL_MATRIX[2].y;
	float arc = MODEL_MATRIX[2].z;
	float g_from = MODEL_MATRIX[3].x;
	float g_to = MODEL_MATRIX[3].y;
	float seed = MODEL_MATRIX[3].z;

	// --- grow: staggered eased flight with arc, spin, scale pop and a glyph flip ---
	float u = clamp((grow_t - delay) / dur, 0.0, 1.0);
	float us = u * u * (3.0 - 2.0 * u);
	float e = ease_out_back(us);
	float hump = sin(HALF_TURN * u);
	float a = seed * TWO_PI;
	vec2 p = mix(start_p, end_p, e) + vec2(cos(a) * 0.45, 1.0) * arc * hump;
	float s = mix(INSTANCE_CUSTOM.x * size, size, us) * (1.0 + pop * hump);
	float ang = spin * TWO_PI * us;
	float settle = smoothstep(0.92, 1.0, u);
	p += vec2(cos(TIME * bob_speed * 0.7 + seed * 40.0), sin(TIME * bob_speed + seed * 40.0)) * bob_amount * settle;
	p -= trail * (0.4 + length(end_p)) * settle;
	float glyph = g_to;
	float fx = 1.0;
	if (abs(g_from - g_to) > 0.5) {
		float f = smoothstep(0.2, 0.8, u);
		glyph = f < 0.5 ? g_from : g_to;
		fx = max(abs(cos(HALF_TURN * f)), 0.04);
	}
	vec3 col = mix(gather_color, COLOR.rgb, smoothstep(0.1, 0.9, u)) + vec3(flash * hump);
	float alpha = smoothstep(0.0, 0.2, u);

	// --- fold back into the heart (switching to the single form) ---
	if (fold_t >= 0.0) {
		float uf = clamp((fold_t - delay * 0.4) / max(fold_dur, 0.001), 0.0, 1.0);
		float ue = uf * uf;
		p = mix(p, vec2(0.0), ue);
		s *= 1.0 - ue;
		ang += ue * TWO_PI * spin;
		alpha *= 1.0 - smoothstep(0.7, 1.0, uf);
	}

	// --- erosion: tint, fade, drifting off in turn, substitute glyphs ---
	float alpha_whole = alpha;
	float lv = smoothstep(0.0, 1.0, level);
	col = mix(col, erosion_tint, lv * tint_strength);
	alpha *= mix(1.0, fade_min_alpha, lv);
	if (level > 0.001) {
		float phase = fract(TIME / shed_period + seed * 3.7);
		float env = sin(HALF_TURN * phase);
		env *= env;
		float chosen = step(fract(seed * 7.31 + 0.13), level * shed_share);
		float da = hash11(seed * 91.0) * TWO_PI;
		p += vec2(cos(da), 0.4 + abs(sin(da))) * shed_distance * env * chosen * level;
		alpha *= 1.0 - (1.0 - shed_min_alpha) * env * chosen;
		p += level * 0.05 * vec2(sin(TIME * 1.3 + seed * 30.0), cos(TIME * 1.1 + seed * 20.0));
	}
	float epoch = TIME / sub_period + seed * 8.0;
	float ia = floor(epoch);
	slots = vec4(glyph,
			sub_first + floor(hash11(ia + seed * 17.0) * sub_count),
			sub_first + floor(hash11(ia + 1.0 + seed * 17.0) * sub_count),
			smoothstep(0.0, 1.0, fract(epoch)));
	blend = blend_max * lv;

	// --- death burst ---
	if (death_t >= 0.0) {
		float t = clamp(death_t / max(death_life, 0.001), 0.0, 1.0);
		float eased = 1.0 - pow(1.0 - t, 3.0);
		float d = hash11(seed * 53.0) * TWO_PI;
		p = end_p + vec2(cos(d), sin(d)) * death_dist * (0.55 + 0.45 * hash11(seed * 29.0)) * eased;
		s *= 1.0 + 0.45 * sin(HALF_TURN * min(t * 1.6, 1.0)) - 0.35 * t;   // swell as they fly out
		col += vec3(0.4) * (1.0 - t);                                       // bright against the dark/pink backdrop
		alpha = alpha_whole * (1.0 - t);   // the burst starts from whole glyphs, not the eroded fade
	}

	alpha *= opacity;
	tint = vec4(col, alpha);
	flip_x = fx;
	if (alpha < HIDDEN_BELOW || s < 0.001) {
		POSITION = vec4(0.0, 0.0, 2.0, 1.0);
		q = vec2(0.0);
	} else {
		vec2 qv = VERTEX.xy;
		float cs = cos(ang);
		float sn = sin(ang);
		vec2 corner = vec2(cs * qv.x * fx - sn * qv.y, sn * qv.x * fx + cs * qv.y) * s;
		vec4 vp = VIEW_MATRIX * vec4(centre, 1.0);
		vp.xy += p + corner;
		POSITION = PROJECTION_MATRIX * vp;
		q = qv;
	}
}

// Coverage of one atlas slot at tile coordinates uv (0..1, y down); 0 outside the tile.
float slot_cov(float slot, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	vec2 tile = vec2(mod(slot + 0.5, atlas_grid.x), floor((slot + 0.5) / atlas_grid.x));
	return texture(glyph_atlas, (floor(tile) + uv) / atlas_grid).a;
}

float glyph_cov(vec2 uv) {
	float a = slot_cov(slots.x, uv);
	if (blend < 0.002) {
		return a;
	}
	float b = mix(slot_cov(slots.y, uv), slot_cov(slots.z, uv), slots.w);
	return mix(a, b, blend);
}

void fragment() {
	vec2 gp = vec2(q.x, -q.y) * (0.5 / glyph_fill) + 0.5;
	float cov = glyph_cov(gp);
	float back = 0.0;
	if (outline_width > 0.0 && gp.x > -0.15 && gp.x < 1.15 && gp.y > -0.15 && gp.y < 1.15) {
		for (int i = 0; i < 4; i++) {
			back = max(back, glyph_cov(gp + OUTLINE_DIRS[i] * outline_width));
		}
		if (hollow > 0.0) {
			cov = mix(cov, clamp(back - cov, 0.0, 1.0), hollow);
			back *= 1.0 - hollow;
		}
		back *= outline_color.a;
	}
	vec3 rgb = outline_color.rgb * back;
	float al = back;
	float grey = dot(tint.rgb, vec3(0.3, 0.59, 0.11));
	vec3 face = max(mix(vec3(grey), tint.rgb, face_saturation) * face_brightness, vec3(0.0));
	rgb = face * cov + rgb * (1.0 - cov);
	al = cov + al * (1.0 - cov);
	ALBEDO = rgb * tint.a;
	ALPHA = al * tint.a;
}
