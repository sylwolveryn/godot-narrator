// The glyph storm (task-030, Spike B moment 4): ONE MultiMesh, ONE draw call. Every instance is a camera-facing glyph
// that starts as a glyph of the floor or a wall top around the player, lifts off, swirls around the player and settles
// back where it started. NOTHING is written per instance: the start point, timing, height, orbit and glyph of instance
// INSTANCE_ID are derived here from a hash of the id and the storm seed, so starting a storm costs a few uniforms on the
// CPU (no buffer build, no hitch). The start cell is looked up in `source_map` (0 void, 0.5 floor, 1 wall; one texel per map
// cell, built once at map build) and in the global reveal mask: glyphs only lift from cells that are drawn and seen.
// Flight of one glyph (u = 0..1 over its own flight, delayed outward from the centre): eased lift (cubic out), orbit around
// the player (whole turns, so it lands where it started) with the orbit widening and the centre following the player,
// the glyph flips once on the way up and once on the way down (squash to a thin line, no random swapping), settles with
// a smoothstep. Nothing flickers: all motion is smooth functions of `storm_t`.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, skip_vertex_transform;

global uniform sampler2D reveal_mask : filter_nearest;

const float PI_ = 3.14159265;
const float TWO_PI = 6.2831853;
const float MASK_GAIN = 1.25;          // MapReveal.MASK_BRIGHTNESS_MAX
const float HIDDEN_BELOW = 0.003;
const float WALL_MIN = 0.75;           // source_map value from which a cell is a wall
const float FLOOR_MIN = 0.25;
const vec2 OUTLINE_DIRS[4] = vec2[4](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));

uniform sampler2D glyph_atlas : filter_linear, repeat_disable;
uniform sampler2D source_map : filter_nearest, repeat_disable;
uniform vec2 atlas_grid = vec2(4.0, 4.0);
uniform vec4 map_params = vec4(40.0, 24.0, 1.0, 1.0);   // map size in cells (xy), world units per cell, wall height
uniform float glyph_fill = 0.8;
uniform vec4 outline_color : source_color = vec4(0.01, 0.005, 0.03, 1.0);
uniform float outline_width = 0.08;

uniform vec4 storm_centre = vec4(0.0, 0.0, 0.0, 6.5);   // xyz where it started, w radius
uniform vec3 storm_follow = vec3(0.0);                  // where the player is now (the swirl follows)
uniform float storm_t = -1.0;                           // seconds since the start; < 0 = no storm (everything collapsed)
uniform float flight = 1.8;                             // seconds one glyph is in the air (lift to landing)
uniform float stagger = 0.78;                           // seconds the take-off wave takes to cross the disc
uniform int storm_seed = 1;
uniform int used = 640;                                 // instances below this id are used (the rest collapse)
uniform float inner_radius = 1.1;
uniform float lift_frac = 0.3;
uniform float settle_frac = 0.34;
uniform float swirl_turns = 1.0;
uniform float inner_boost = 1.0;
uniform float swirl_dir = 1.0;
uniform float spiral_out = 0.3;
uniform float follow = 1.0;
uniform float wobble = 0.3;
uniform float spin_amount = 0.35;
uniform float peak_height = 2.6;
uniform float height_var = 0.5;
uniform float ground_lift = 0.03;
uniform float size_ground = 0.1;
uniform float size_air = 0.24;
uniform float size_var = 0.4;
uniform float pop = 0.25;
uniform int floor_n = 6;
uniform int wall_n = 3;
uniform int storm_n = 10;
uniform vec3 floor_color = vec3(0.36, 0.4, 0.62);
uniform vec3 wall_color = vec3(0.45, 0.58, 0.9);
uniform vec3 air_color = vec3(0.82, 0.88, 1.0);
uniform vec3 storm_tint = vec3(0.85, 0.8, 1.0);
uniform float tint_mix = 0.6;
uniform float memory_bright = 0.55;
uniform float glow_strength = 0.35;
uniform float air_alpha = 0.95;

varying vec2 q;
varying vec4 tint;
varying flat float slot;
varying flat float glow;

// Hash of (instance, stream): 0..1. PCG output function, integer only (no sin(), the same on every driver).
float rnd(uint id, uint k) {
	uint x = id * 11u + k + uint(storm_seed) * 1013u;
	x = x * 747796405u + 2891336453u;
	x = ((x >> ((x >> 28u) + 4u)) ^ x) * 277803737u;
	x = (x >> 22u) ^ x;
	return float(x) * (1.0 / 4294967295.0);
}

void vertex() {
	uint id = uint(INSTANCE_ID);
	float cell_size = map_params.z;
	float radius = storm_centre.w;
	float a0 = rnd(id, 0u) * TWO_PI;
	float rr = mix(inner_radius, radius, sqrt(rnd(id, 1u)));
	vec2 p0 = storm_centre.xz + vec2(cos(a0), sin(a0)) * rr;
	ivec2 cell = ivec2(floor(p0 / cell_size));
	bool ok = storm_t >= 0.0 && INSTANCE_ID < used && cell.x >= 0 && cell.y >= 0 && float(cell.x) < map_params.x && float(cell.y) < map_params.y;
	float src = 0.0;
	vec4 m = vec4(0.0);
	if (ok) {
		src = texelFetch(source_map, cell, 0).r;
		m = texelFetch(reveal_mask, cell, 0);
		bool wall = src > WALL_MIN;
		float vis = m.r * MASK_GAIN * (wall ? 1.0 : m.a);
		ok = src > FLOOR_MIN && vis > 0.05;
	}
	float delay = stagger * (0.7 * (rr - inner_radius) / max(radius - inner_radius, 0.001) + 0.3 * rnd(id, 2u));
	float u = clamp((storm_t - delay) / max(flight, 0.001), 0.0, 1.0);
	if (!ok || u <= 0.0 || u >= 1.0) {
		POSITION = vec4(0.0, 0.0, 2.0, 1.0);
		q = vec2(0.0);
		tint = vec4(0.0);
		slot = 0.0;
		glow = 0.0;
	} else {
		bool wall = src > WALL_MIN;
		// --- height profile: cubic-out lift, smoothstep settle ---
		float x = clamp(u / lift_frac, 0.0, 1.0);
		float up = 1.0 - pow(1.0 - x, 3.0);
		float y2 = clamp((1.0 - u) / settle_frac, 0.0, 1.0);
		float down = y2 * y2 * (3.0 - 2.0 * y2);
		float h = up * down;
		// --- orbit: whole turns so the glyph lands where it started; more turns near the player ---
		float inner = 1.0 - (rr - inner_radius) / max(radius - inner_radius, 0.001);
		float turns = max(floor(swirl_turns + inner_boost * inner + 0.5), 1.0);
		float ease_u = mix(u, u * u * (3.0 - 2.0 * u), 0.5);
		float theta = swirl_dir * turns * TWO_PI * ease_u;
		float ang = a0 + theta;
		float rad_now = rr * (1.0 + spiral_out * h);
		vec2 c = mix(storm_centre.xz, storm_follow.xz, follow * h);
		float base_y = wall ? map_params.w + ground_lift : ground_lift;
		float tall = peak_height * (1.0 - height_var * rnd(id, 3u));
		float y = base_y + h * tall + wobble * h * sin(theta * 1.5 + rnd(id, 4u) * TWO_PI);
		vec3 world = vec3(c.x + cos(ang) * rad_now, y, c.y + sin(ang) * rad_now);
		// --- glyph: its own floor / wall glyph on the ground, a storm glyph in the air, a flip at each end ---
		float g_from = wall ? float(floor_n) + floor(rnd(id, 5u) * float(wall_n)) : floor(rnd(id, 5u) * float(floor_n));
		float g_to = float(floor_n + wall_n) + floor(rnd(id, 6u) * float(storm_n));
		bool flipped = h > 0.5;
		slot = flipped ? g_to : g_from;
		float fx = max(abs(cos(PI_ * h)), 0.06);
		// --- size, spin, colour ---
		float s = mix(size_ground, size_air * (1.0 - size_var * rnd(id, 7u)), h) * (1.0 + pop * sin(PI_ * h));
		float spin = (rnd(id, 8u) - 0.5) * 2.0 * spin_amount * TWO_PI * sin(PI_ * u);
		float cs = cos(spin);
		float sn = sin(spin);
		float mem = mix(memory_bright, 1.0, m.g);
		vec3 ground_col = (wall ? wall_color : floor_color) * mem;
		vec3 air_col = mix(air_color, storm_tint, tint_mix) * (0.75 + 0.5 * rnd(id, 9u));
		vec3 col = mix(ground_col, air_col, smoothstep(0.0, 0.6, h));
		float alpha = smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.9, 1.0, u)) * mix(1.0, air_alpha, h);
		tint = vec4(col, alpha);
		glow = glow_strength * h;

		vec4 vp = VIEW_MATRIX * vec4(world, 1.0);
		vec2 qv = VERTEX.xy;
		vp.xy += vec2(cs * qv.x * fx - sn * qv.y, sn * qv.x * fx + cs * qv.y) * s;
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
	ALBEDO = (rgb + storm_tint * halo) * tint.a;
	ALPHA = al * tint.a;
}
