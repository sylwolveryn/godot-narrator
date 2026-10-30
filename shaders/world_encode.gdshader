shader_type spatial;
render_mode unshaded;
// World material: draws data, not colour (see world_encoding.gdshaderinc). One ShaderMaterial per
// cell type, built by MapLoader. R = material id, G = luminance (player light, reveal fade and
// hazard pulse already applied), B = state (visible: palette offset, remembered: memory amount).
// Needs the global shader parameters player_pos, light_params, look_params, map_params and the
// reveal_mask texture (one texel per map cell), set by AsciiPostProcess and MapReveal.
#include "res://shaders/world_encoding.gdshaderinc"

global uniform vec2 player_pos;
// x = light inner radius, y = outer radius (world units), z = ambient luminance.
global uniform vec4 light_params;
// x = hue noise scale, y = hue noise amplitude, z = fine-octave share, w = height amplitude.
global uniform vec4 look_params;
// x = map cell size in world units.
global uniform vec4 map_params;
// Per cell: r = reveal brightness / 1.25, g = seen fraction (0 = remembered, 1 = seen), b = glint.
global uniform sampler2D reveal_mask : filter_nearest;

uniform int material_id = 1;
// Luminance of lit materials in full light.
uniform float lit_l = 1.0;
// 0 or more: emissive, fixed luminance independent of the player light.
uniform float emissive_l = -1.0;
uniform float pulse_amp = 0.0;
uniform float pulse_hz = 0.0;
// Spatial frequency of the static world noise that offsets the pulse phase per position.
uniform float pulse_noise_scale = 0.35;
// Height that maps to 1 in the palette height term (also the box height for the edge test).
uniform float height_ref = 1.0;
// Structure look for lit boxes (walls): face shading, rim edges and per-glyph detail noise.
uniform bool shade_faces = false;
// Luminance factor of top faces, of side faces turned to the player and away from it.
uniform float face_top = 1.0;
uniform float face_side_lit = 0.9;
uniform float face_side_dark = 0.45;
// Side faces darken toward the foot of the wall: factor at y = 0 (1 at the top).
uniform float foot_shade = 0.6;
// Box edges (world units wide) get extra luminance, and a cool tint through the palette offset.
uniform float edge_width = 0.12;
uniform float edge_boost = 0.3;
// Detail noise: frequency per world unit (about one glyph cell) and palette-offset amplitude.
uniform float detail_scale = 7.0;
uniform float detail_amp = 0.45;

varying vec3 world_pos;
varying vec3 world_centre;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_centre = MODEL_MATRIX[3].xyz;
}

// Luminance factor of a face: top faces and faces turned toward the player are bright, faces
// turned away and the foot of the wall are dark, box edges catch extra light.
float face_shade(vec3 wn, float light, float edge_k) {
	float shade = face_top;
	if (abs(wn.y) < 0.5) {
		vec2 to_player = player_pos - world_pos.xz;
		float facing = clamp(dot(wn.xz, to_player / max(length(to_player), 0.001)) * 0.5 + 0.5, 0.0, 1.0);
		shade = mix(face_side_dark, face_side_lit, facing) * mix(foot_shade, 1.0, clamp(world_pos.y / height_ref, 0.0, 1.0));
	}
	return shade + edge_k * edge_boost * mix(0.4, 1.0, light);
}

void fragment() {
	// The map cell is taken from the mesh origin so faces on a cell border never read a neighbour.
	ivec2 cell = ivec2(floor(world_centre.xz / map_params.x));
	vec3 mask = texelFetch(reveal_mask, cell, 0).rgb;
	float fade = mask.r * 1.25;
	float seen = mask.g;
	if (fade < 0.004) {
		discard;
	}

	// Box edge factor (1 on an edge, 0 inside a face): distance to the nearest edge of the face.
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 local = world_pos - world_centre;
	vec3 half_size = vec3(0.5 * map_params.x, 0.5 * height_ref, 0.5 * map_params.x);
	vec3 gap = half_size - abs(local);
	vec3 an = abs(wn);
	float to_edge = an.y > 0.5 ? min(gap.x, gap.z) : (an.x > 0.5 ? min(gap.y, gap.z) : min(gap.x, gap.y));
	float edge_k = 1.0 - smoothstep(0.0, max(edge_width, 0.001), to_edge);

	float l_seen;
	if (emissive_l >= 0.0) {
		float phase = vnoise(world_pos.xz * pulse_noise_scale) * TAU * 2.0;
		l_seen = emissive_l + pulse_amp * sin(TAU * pulse_hz * TIME + phase);
	} else {
		float d = distance(world_pos.xz, player_pos);
		float light = 1.0 - smoothstep(light_params.x, light_params.y, d);
		l_seen = lit_l * mix(light_params.z, 1.0, light);
		if (shade_faces) {
			l_seen = clamp(l_seen * face_shade(wn, light, edge_k), 0.0, 1.0);
		}
	}
	// A remembered cell is full luminance (the post shader caps its density); it settles into the
	// live luminance while it turns into a seen cell.
	float l_out = mix(min(fade, 1.0), l_seen * fade, seen);

	vec2 wp = world_pos.xz;
	float n_coarse = vnoise(wp * look_params.x) * 2.0 - 1.0;
	float n_fine = vnoise(wp * look_params.x * 10.0) * 2.0 - 1.0;
	float n_detail = shade_faces ? (vnoise(wp * detail_scale) * 2.0 - 1.0) * detail_amp : 0.0;
	float t = look_params.y * (n_coarse + look_params.z * n_fine) + n_detail
			+ look_params.w * clamp(world_pos.y / height_ref, 0.0, 1.0)
			+ mask.b * 0.45;

	float state = seen < 0.999 ? enc_memory(1.0 - seen) : enc_live(t);
	ALBEDO = vec3(enc_id(material_id), enc_l(l_out), state);
}
