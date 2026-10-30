shader_type canvas_item;
// ASCII post-process (docs/visual_direction.md). Reads the encoded 3D render (see
// world_encoding.gdshaderinc) at the centre of every glyph cell, then picks the glyph ramp and
// palette row by material id, draws the glyph from the SDF atlas (ramp morph, never a swap),
// colours it from the palette LUT and adds glow, bloom, depth of field and a vignette.
// All uniforms are set by AsciiPostProcess from AsciiConfig, PaletteConfig, LightConfig,
// HazardFxConfig and GlyphFxConfig. No per-frame random: variation is time plus static world noise.
#include "res://shaders/glyph_sdf.gdshaderinc"
#include "res://shaders/world_encoding.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D glyph_atlas : filter_linear;
uniform sampler2D palette_lut : filter_linear;
// 16 x 8 texels, row = material id: texels 0..14 glyph indices, texel 15 = ramp length.
uniform sampler2D ramp_lut : filter_nearest;
uniform int atlas_cols = 8;
uniform vec2 atlas_tile_uv = vec2(0.125, 0.125);

uniform vec2 cell_px = vec2(10.0, 14.0);
uniform vec2 player_px = vec2(960.0, 540.0);
// World xz position of screen pixel (0, 0) and world units per screen pixel (static noise anchor).
uniform vec2 view_origin = vec2(0.0);
uniform float world_per_px = 0.0111;

uniform vec3 bg_centre = vec3(0.04, 0.06, 0.12);
uniform vec3 bg_edge = vec3(0.01, 0.015, 0.035);
uniform vec3 light_tint = vec3(1.0, 0.76, 0.48);
uniform vec2 light_px = vec2(84.0, 154.0);
uniform float light_tint_strength = 0.5;
uniform float bg_pool = 0.07;

uniform float morph_band = 0.25;
uniform float scale_dip = 0.92;
uniform float glow_boost = 0.15;
uniform float edge_near = 0.06;
uniform float edge_far = 0.22;
uniform float dof_px = 112.0;
uniform float dof_slide = 0.2;

uniform float glow_radius = 0.35;
uniform float glow_strength = 0.8;
uniform bool bloom_on = true;
uniform float bloom_sigma_px = 8.0;
uniform float bloom_strength = 0.5;
uniform float wall_rim = 0.5;
// Glow weight per material id (0 = none). Walls use the rim rule instead.
uniform float emissive_weight[8];

uniform float vignette_strength = 0.35;
uniform float vignette_radius = 0.75;
uniform float mem_cap = 0.45;
uniform float mem_mix = 0.15;

uniform float corrupt_warp_amp = 0.35;
uniform float corrupt_period = 3.2;
uniform float corrupt_hue_hz = 0.3;

const int ID_VOID = 0;
const int ID_WALL = 1;
const int ID_CORRUPT = 5;
const int ROW_CORRUPT_ALT = 6;
const int ROW_MEMORY = 7;

struct Cell {
	int id;
	float l;
	float state;
};

Cell read_cell(ivec2 c) {
	ivec2 p = c * ivec2(cell_px) + ivec2(cell_px * 0.5);
	p = clamp(p, ivec2(0), textureSize(screen_tex, 0) - ivec2(1));
	vec3 raw = texelFetch(screen_tex, p, 0).rgb;
	Cell cell;
	cell.id = dec_id(raw.r);
	cell.l = dec_l(raw.g);
	cell.state = raw.b;
	return cell;
}

vec3 palette(int row, float u) {
	return texture(palette_lut, vec2(clamp(u, 0.0, 1.0) * 0.99609375 + 0.001953125, (float(row) + 0.5) / 16.0)).rgb;
}

int ramp_len(int id) {
	return int(texelFetch(ramp_lut, ivec2(15, id), 0).r * 255.0 + 0.5);
}

int ramp_glyph(int id, int k) {
	return int(texelFetch(ramp_lut, ivec2(k, id), 0).r * 255.0 + 0.5);
}

// Light a neighbouring (or own) emissive cell throws on this pixel; `to_px` is the vector from
// the pixel to that cell's centre.
vec3 glow_of(Cell c, vec2 to_px) {
	if (c.id <= 0 || c.id > 7 || dec_is_memory(c.state)) {
		return vec3(0.0);
	}
	float w = emissive_weight[c.id];
	if (w <= 0.0) {
		return vec3(0.0);
	}
	float u = clamp(c.l + dec_t(c.state), 0.0, 1.0);
	vec3 col = c.id == ID_CORRUPT ? mix(palette(ID_CORRUPT, u), palette(ROW_CORRUPT_ALT, u), 0.5) : palette(c.id, u);
	float g = exp(-dot(to_px, to_px) / (2.0 * bloom_sigma_px * bloom_sigma_px));
	return col * (c.l * w * g);
}

void fragment() {
	vec2 frag = FRAGCOORD.xy;
	vec2 view = 1.0 / SCREEN_PIXEL_SIZE;
	ivec2 cell = ivec2(floor(frag / cell_px));
	vec2 local_px = frag - vec2(cell) * cell_px;

	Cell me = read_cell(cell);
	Cell nb_l = read_cell(cell + ivec2(-1, 0));
	Cell nb_r = read_cell(cell + ivec2(1, 0));
	Cell nb_u = read_cell(cell + ivec2(0, -1));
	Cell nb_d = read_cell(cell + ivec2(0, 1));

	float pdist = length(frag - player_px);
	float light = 1.0 - smoothstep(light_px.x, light_px.y, pdist);
	float half_diag = length(0.5 * view);
	float vig = 1.0 - vignette_strength * smoothstep(vignette_radius, 1.0, length(frag - 0.5 * view) / half_diag);
	vec3 bg = mix(bg_centre, bg_edge, smoothstep(0.0, 0.9, pdist / half_diag)) + light_tint * (bg_pool * exp(-pow(pdist / (light_px.y * 0.7), 2.0)));

	vec3 bloom = vec3(0.0);
	if (bloom_on) {
		vec2 own = 0.5 * cell_px - local_px;
		bloom = glow_of(me, own)
				+ glow_of(nb_l, own + vec2(-cell_px.x, 0.0))
				+ glow_of(nb_r, own + vec2(cell_px.x, 0.0))
				+ glow_of(nb_u, own + vec2(0.0, -cell_px.y))
				+ glow_of(nb_d, own + vec2(0.0, cell_px.y));
	}
	vec3 col = (bg + bloom * bloom_strength) * vig;

	int n = me.id > 0 && me.id < 8 ? ramp_len(me.id) : 0;
	if (n >= 2) {
		bool mem = dec_is_memory(me.state);
		float m = mem ? dec_memory_left(me.state) : 0.0;
		float t = mem ? 0.0 : dec_t(me.state);
		float l_eff = me.l * vig;
		if (mem) {
			l_eff = min(l_eff, mix(1.0, mem_cap, m));
		}

		vec2 wp = view_origin + frag * world_per_px;
		float drive = l_eff;
		vec2 warp = vec2(0.0);
		float hue = 0.0;
		if (me.id == ID_CORRUPT) {
			// Corruption breathes: slow flow noise warps the glyph and picks which glyph it blends toward.
			float period = max(corrupt_period, 0.1);
			vec2 q = wp * 2.0 + vec2(TIME / period, TIME / (period * 1.37));
			warp = (vec2(vnoise(q), vnoise(q + 17.31)) - 0.5) * corrupt_warp_amp;
			float pick = vnoise(wp * 3.0 + vec2(-TIME / (period * 1.6), TIME / (period * 2.1)) + 5.0);
			drive = l_eff * 0.35 + pick * 0.65 * smoothstep(0.0, 0.3, l_eff);
			hue = 0.5 + 0.5 * sin(TAU * (corrupt_hue_hz * TIME + vnoise(wp * 0.7)));
		}

		// Ramp morph (stateless): any change of the drive value becomes a continuous shape blend.
		float s = clamp(drive, 0.0, 1.0) * float(n - 1);
		int i0 = min(int(floor(s)), n - 2);
		float blend = smoothstep(0.5 - morph_band, 0.5 + morph_band, s - float(i0));
		float bump = morph_bump(blend);
		float dof = smoothstep(dof_px, dof_px * 2.5, pdist);
		float scale = 1.0 - (1.0 - scale_dip) * bump;
		vec2 local = (local_px / cell_px - 0.5) / scale + 0.5 - warp;
		float d = glyph_sdf_morph(glyph_atlas, atlas_cols, atlas_tile_uv, ramp_glyph(me.id, i0), ramp_glyph(me.id, i0 + 1), blend, local);
		float cover = glyph_alpha(d, mix(edge_near, edge_far, dof));

		// Colour from the palette gradient; remembered cells use the dim memory gradient.
		float u = clamp(l_eff + t, 0.0, 1.0);
		vec3 gcol = me.id == ID_CORRUPT ? mix(palette(ID_CORRUPT, u), palette(ROW_CORRUPT_ALT, u), hue) : palette(me.id, u);
		if (mem) {
			vec3 dim = mix(palette(ROW_MEMORY, clamp(l_eff / max(mem_cap, 0.01), 0.0, 1.0)), palette(me.id, 0.5), mem_mix);
			gcol = mix(gcol, dim, m);
		}
		gcol = mix(gcol, gcol * light_tint, light * light_tint_strength * (1.0 - m));
		gcol = mix(gcol, bg, dof * dof_slide);

		// Halo: emissive types glow in full; walls only get a rim glow inside the player light.
		float e = mem ? 0.0 : emissive_weight[me.id];
		if (me.id == ID_WALL && !mem) {
			bool rim = nb_l.id != ID_WALL || nb_r.id != ID_WALL || nb_u.id != ID_WALL || nb_d.id != ID_WALL;
			e = rim ? light * wall_rim : 0.0;
		}
		float halo = exp(-max(0.5 - d, 0.0) * 2.0 / glow_radius) * (1.0 + glow_boost * bump);
		col += gcol * (halo * glow_strength * e * vig);
		col = mix(col, gcol, cover);
	}
	// Static screen-space dither (interleaved gradient noise, not per frame): hides 8-bit banding in the dark gradients.
	float dither = (fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715)))) - 0.5) / 255.0;
	COLOR = vec4(clamp(col + dither, vec3(0.0), vec3(1.0)), 1.0);
}
