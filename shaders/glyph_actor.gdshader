// Glyph actors of the glyph world (task-033): the player's identity glyph standing in the iso world, and the glyph
// fragments it sheds and breaks into. ONE MultiMesh (one draw call) of camera-facing quads; each quad carries the
// glyph (from a small runtime atlas of font-rendered tiles, see PlayerGlyphView) AND its soft halo, composed in
// premultiplied alpha (glyph and dark backing blend over the world, the halo adds light).
// Per instance: transform origin = glyph centre, scale = quad half-size, COLOR = glyph tint (a = opacity),
// INSTANCE_CUSTOM = (base atlas slot, corrupt slots B + 64 * C, erosion level 0..1, morph B->C 0..1).
// Erosion (level): the base glyph blends continuously into the corrupt glyph, the image warps in slow waves
// (no per-frame random, only TIME) and a violet ghost image slides beside it. Opacity 0 collapses the quad.
// Crystal glow (task-056): the glyph is split into facets that each drift slowly through a small palette, a few
// facets sparkle; the halo follows the palette. Lean / stretch (task-057): the transform's Y column carries
// (lean, stretch, 0) * size for the player glyph (a plain uniform scale gives lean 0, stretch 1), pivoting at the
// glyph's foot so the glyph leans into its motion and stretches / squashes with the acceleration.
// Understanding look (task-066, PlayerGlyphView): `hollow` 1 draws only the glyph's edge band (no filled body, no dark
// backing), the face colour is graded by `face_saturation` / `face_brightness` (1, 1 = plain); the glow is scaled on the
// CPU (halo_intensity, crystal_strength, crystal_sparkle). Defaults reproduce the look before.
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, fog_disabled;

#include "res://shaders/glyph_halo.gdshaderinc"

const float TWO_PI = 6.2831853;
const float HIDDEN_BELOW = 0.003;
const float SLOT_PACK = 64.0;
const int CRYSTAL_MAX = 6;                // AvatarFxConfig.crystal_max_colors
const float MIN_STRETCH = 0.2;
const vec2 OUTLINE_DIRS[4] = vec2[4](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));

uniform sampler2D glyph_atlas : filter_linear, repeat_disable;
uniform vec2 atlas_grid = vec2(5.0, 4.0);       // tiles per row / column
uniform float lift = 0.9;                       // towards the camera, world units
uniform float glyph_fill = 0.42;                // glyph tile size / quad size
uniform float blend_max = 0.85;                 // share of the corrupt glyph at level 1
uniform float warp_max = 0.07;                  // warp at level 1, fraction of the glyph tile
uniform float warp_period = 3.2;
uniform float ghost_offset = 0.09;
uniform vec3 ghost_color = vec3(0.7, 0.3, 1.0);
uniform vec4 outline_color : source_color = vec4(0.015, 0.01, 0.03, 0.9);
uniform float outline_width = 0.035;            // fraction of the glyph tile
uniform vec3 halo_color = vec3(1.0, 0.82, 0.5);
uniform float halo_intensity = 0.75;
uniform float halo_pool = 0.35;
uniform float halo_breath_amount = 0.08;
uniform float halo_breath_period = 4.0;
uniform vec4 crystal_palette[CRYSTAL_MAX];
uniform float crystal_count = 0.0;              // colours in use (0 = crystal glow off)
uniform float crystal_speed = 0.08;             // palette cycles per second
uniform float crystal_strength = 0.45;
uniform float crystal_facets = 5.0;
uniform float crystal_sparkle = 0.04;
uniform float hollow = 0.0;
uniform float face_saturation = 1.0;
uniform float face_brightness = 1.0;
uniform float halo_ref_size = 1.5;              // quad half-size of the player glyph; the halo of smaller quads (fragments) shrinks with its cube

varying vec2 q;
varying vec4 tint;
varying flat vec4 slots;                        // base, B, C, morph
varying flat float level;
varying flat float h_k;
varying flat float h_pool_y;
varying flat float h_squash;

void vertex() {
	tint = COLOR;
	if (COLOR.a < HIDDEN_BELOW) {
		POSITION = vec4(0.0, 0.0, 2.0, 1.0);
		q = vec2(0.0);
		slots = vec4(0.0);
		level = 0.0;
		h_k = 0.0;
		h_pool_y = 0.0;
		h_squash = 1.0;
	} else {
		vec3 c = MODEL_MATRIX[3].xyz;
		float size = length(MODEL_MATRIX[0].xyz);
		vec3 r = INV_VIEW_MATRIX[0].xyz;
		vec3 u = INV_VIEW_MATRIX[1].xyz;
		vec3 to_cam = INV_VIEW_MATRIX[2].xyz;
		vec3 shape = MODEL_MATRIX[1].xyz / max(size, 0.0001);
		float stretch = max(shape.y, MIN_STRETCH);
		float foot_y = VERTEX.y + glyph_fill;
		vec2 v = vec2(VERTEX.x * inversesqrt(stretch) + shape.x * foot_y, foot_y * stretch - glyph_fill);
		vec3 pos = c + (r * v.x + u * v.y) * size + to_cam * lift;
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pos, 1.0);
		q = VERTEX.xy;
		float cb = mod(INSTANCE_CUSTOM.y + 0.5, SLOT_PACK);
		slots = vec4(INSTANCE_CUSTOM.x, floor(cb), floor((INSTANCE_CUSTOM.y + 0.5) / SLOT_PACK), INSTANCE_CUSTOM.w);
		level = INSTANCE_CUSTOM.z;
		float rel = min(size / halo_ref_size, 1.0);
		h_k = rel * rel * rel;
		h_pool_y = -c.y * u.y / size;
		h_squash = abs(to_cam.y);
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

float crystal_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// The palette colour at phase t (0..1 wraps), blended smoothly between neighbours.
vec3 crystal_at(float t) {
	float pp = fract(t) * crystal_count;
	int i0 = min(int(pp), CRYSTAL_MAX - 1);
	int i1 = int(mod(float(i0 + 1), max(crystal_count, 1.0)));
	return mix(crystal_palette[i0].rgb, crystal_palette[i1].rgb, smoothstep(0.0, 1.0, fract(pp)));
}

// The glyph: the base slot blended into the (morphing) corrupt slot by the erosion level.
float glyph_cov(vec2 uv, float blend) {
	float a = slot_cov(slots.x, uv);
	if (blend < 0.002) {
		return a;
	}
	float b = slot_cov(slots.y, uv);
	if (slots.w > 0.002) {
		b = mix(b, slot_cov(slots.z, uv), slots.w);
	}
	return mix(a, b, blend);
}

void fragment() {
	vec2 gp = vec2(q.x, -q.y) * (0.5 / glyph_fill) + 0.5;   // glyph tile coordinates
	float blend = blend_max * smoothstep(0.0, 1.0, level);
	float wave = TIME * TWO_PI / warp_period;
	float amp = warp_max * level;
	vec2 wp = gp + amp * vec2(
		0.6 * sin(gp.y * 9.0 + wave) + 0.4 * sin(gp.y * 23.0 - wave * 1.7),
		0.5 * sin(gp.x * 7.0 + wave * 0.8));
	float cov = glyph_cov(wp, blend);
	float ghost = 0.0;
	if (level > 0.01) {
		ghost = glyph_cov(wp + vec2(ghost_offset * level, 0.0), blend) * 0.8;
	}
	float back = 0.0;
	if (outline_width > 0.0 && gp.x > -0.15 && gp.x < 1.15 && gp.y > -0.15 && gp.y < 1.15) {
		for (int i = 0; i < 4; i++) {
			back = max(back, glyph_cov(wp + OUTLINE_DIRS[i] * outline_width, blend));
		}
		if (hollow > 0.0) {
			// Hollow: the edge band around the glyph becomes the drawn glyph, the body and its dark backing go.
			cov = mix(cov, clamp(back - cov, 0.0, 1.0), hollow);
			back *= 1.0 - hollow;
		}
		back *= outline_color.a;
	}
	// glyph over ghost over dark backing, all premultiplied
	vec3 rgb = outline_color.rgb * back;
	float al = back;
	rgb = ghost_color * ghost + rgb * (1.0 - ghost);
	al = ghost + al * (1.0 - ghost);
	vec3 face = tint.rgb;
	vec3 halo_tint = mix(halo_color, ghost_color, level);
	if (crystal_count > 0.5 && crystal_strength > 0.0) {
		float k = crystal_strength * (1.0 - level);
		vec2 facet = floor(gp * crystal_facets);
		float fh = crystal_hash(facet);
		vec3 cc = crystal_at(TIME * crystal_speed + fh * 0.35);
		float spark = step(1.0 - crystal_sparkle, crystal_hash(facet + floor(TIME * 1.5 + fh * 7.0)));
		face = mix(tint.rgb, cc, k) + cc * spark * 0.6 * (1.0 - level);
		halo_tint = mix(halo_tint, crystal_at(TIME * crystal_speed), k * 0.6);
	}
	float grey = dot(face, vec3(0.3, 0.59, 0.11));
	face = max(mix(vec3(grey), face, face_saturation) * face_brightness, vec3(0.0));
	rgb = face * cov + rgb * (1.0 - cov);
	al = cov + al * (1.0 - cov);
	rgb *= tint.a;
	al *= tint.a;
	float breath = 1.0 + halo_breath_amount * sin(TIME * TWO_PI / halo_breath_period);
	float glow = halo_shape(q, h_pool_y, h_squash, halo_pool) * halo_intensity * breath * tint.a * h_k;
	ALBEDO = rgb + halo_tint * glow;
	ALPHA = al;
}
