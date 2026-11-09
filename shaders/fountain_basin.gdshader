// Fountain basin (task-101, FountainBasin): the stone rim and the water of a gargoyle fountain as real geometry fitted
// to the footprint, so it stays on its floor cells at every camera yaw. Glyphs live on the faces like the world's:
// rim faces resolve a glyph grid along the face (sides) or the floor plane (tops) and pick the stone glyph from the
// atlas density ramp; the water draws flowing "~" glyphs with ripple rings out of the splash point. Self-lit: the
// water glows and lights the inner faces of the rim (the concept's luminous pool), the outer faces fall off to dark.
// Per vertex: COLOR.r = 1 on faces that look into the basin, COLOR.g = 1 on the water. Cost: 1 atlas fetch per
// fragment + ~30 ALU, a few dozen triangles per fountain.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, fog_disabled;

const float ATLAS_COLS = 8.0;    // GlyphAtlasSpec.COLUMNS
const float ATLAS_ROWS = 6.0;    // GlyphAtlasSpec.ROWS
const float ROW_STONE = 0.0;     // wall ramp: . : + x X # M
const float ROW_WATER = 3.0;     // corruption ramp: ` ~ ? % & $ #
const float COL_WAVE = 2.0;      // "~"
const float COL_RIPPLE = 1.0;    // "`"
const float TOP_NORMAL_Y = 0.7;

uniform sampler2D glyph_atlas : filter_linear_mipmap, repeat_disable;
uniform vec2 glyph_cell = vec2(0.06, 0.1);   // world units (width, height)
uniform float glyph_crop = 0.62;             // fraction of the atlas tile width shown per cell
uniform vec3 stone_dark = vec3(0.1, 0.12, 0.22);
uniform vec3 stone_bright = vec3(0.55, 0.85, 1.0);
uniform vec3 water_deep = vec3(0.02, 0.18, 0.4);
uniform vec3 water_bright = vec3(0.7, 0.97, 1.0);
uniform float rim_height = 0.2;              // world units, for the height gradient
uniform vec2 splash = vec2(0.0, 0.3);        // local xz of the falling water's landing point
uniform float ripple_spacing = 0.12;         // world units between ripple rings
uniform float ripple_speed = 0.25;           // world units per second
uniform float flow_speed = 0.6;              // glyph rows per second the wave pattern drifts
uniform vec3 lip_color = vec3(0.4, 0.9, 1.0);   // the water's glow on the inner faces and the lip
uniform float water_glow = 0.3;              // share of the bright colour in the water's ground
uniform float water_pulse = 0.12;            // slow brightness pulse of the water
uniform float pulse_speed = 1.3;             // radians per second
uniform float heart_falloff = 3.0;           // per world unit: how fast the glow fades from the landing point
uniform vec4 tint = vec4(1.0);               // reveal: memory tint (rgb) * visibility (a)
uniform float background = 0.18;             // brightness of the face behind the glyphs (keeps the rim solid)

varying vec3 lp;
varying vec3 ln;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Coverage (0..1) of the atlas glyph (col, row) at the glyph-grid coordinate g; gradients from the continuous g so the
// cell borders do not pick a blurry mip.
float glyph(float col, float row, vec2 g) {
	vec2 f = fract(g);
	vec2 uv = vec2((col + 0.5 + (f.x - 0.5) * glyph_crop) / ATLAS_COLS, (row + 0.03 + f.y * 0.94) / ATLAS_ROWS);
	vec2 sc = vec2(glyph_crop / ATLAS_COLS, 0.94 / ATLAS_ROWS);
	float cov = textureGrad(glyph_atlas, uv, dFdx(g) * sc, dFdy(g) * sc).r;
	return clamp((cov - 0.08) * 1.5, 0.0, 1.0);
}

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	bool water = COLOR.g > 0.5;
	bool inner = COLOR.r > 0.5;
	vec2 g;
	if (abs(ln.y) > TOP_NORMAL_Y) {
		g = vec2(lp.x, lp.z) / glyph_cell;
	} else {
		vec3 t = normalize(vec3(ln.z, 0.0, -ln.x));
		g = vec2(dot(lp, t), -lp.y) / glyph_cell;
	}
	float row;
	float col;
	float lum;
	vec3 fg;
	vec3 bg;
	if (water) {
		g.y -= TIME * flow_speed;
		vec2 cell = floor(g);
		vec2 c = (cell + 0.5) * glyph_cell;
		c.y += TIME * flow_speed * glyph_cell.y;
		float d = length(c - splash);
		float ring = 0.5 + 0.5 * cos((d - TIME * ripple_speed) / ripple_spacing * 6.2831);
		ring *= exp(-d * 2.0);
		float n = hash(cell + floor(TIME * 2.0) * 0.37);
		float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
		lum = clamp(0.45 + ring * 0.9 + n * 0.2, 0.0, 1.0);
		row = ROW_WATER;
		col = ring > 0.4 ? COL_RIPPLE : COL_WAVE;
		fg = water_bright * (0.85 + 0.35 * lum);
		// Brightest at the landing point, darker cyan towards the rim: the pool reads as the light source.
		float heart = exp(-d * heart_falloff);
		bg = mix(water_deep, water_bright, clamp(water_glow * 0.6 + heart * 0.7 + pulse * water_pulse + ring * 0.3, 0.0, 1.0));
		float a = glyph(col, row, g);
		ALBEDO = mix(bg, fg, a) * tint.rgb;
	} else {
		vec2 cell = floor(g);
		float h = clamp(lp.y / max(rim_height, 0.001), 0.0, 1.0);
		float top = abs(ln.y) > TOP_NORMAL_Y ? 1.0 : 0.0;
		lum = clamp(0.3 + 0.35 * h + top * 0.2 + (hash(cell) - 0.5) * 0.35, 0.0, 1.0);
		col = 1.0 + floor(lum * 6.99);
		row = ROW_STONE;
		fg = mix(stone_dark * 1.6, stone_bright, lum);
		// The inner faces and the lip catch the water's glow; the outside stays plain dark stone.
		float lit = inner ? (top > 0.5 ? 0.55 : 0.35 + 0.65 * h) : 0.0;
		fg = mix(fg, lip_color, lit);
		bg = mix(stone_dark * background, lip_color * 0.25, lit * 0.6);
		float a = glyph(col, row, g);
		ALBEDO = mix(bg, fg, a) * tint.rgb;
	}
}
