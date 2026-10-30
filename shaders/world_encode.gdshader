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
// Height that maps to 1 in the palette height term.
uniform float height_ref = 1.0;

varying vec3 world_pos;
varying vec3 world_centre;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_centre = MODEL_MATRIX[3].xyz;
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

	float l_seen;
	if (emissive_l >= 0.0) {
		float phase = vnoise(world_pos.xz * pulse_noise_scale) * TAU * 2.0;
		l_seen = emissive_l + pulse_amp * sin(TAU * pulse_hz * TIME + phase);
	} else {
		float d = distance(world_pos.xz, player_pos);
		float light = 1.0 - smoothstep(light_params.x, light_params.y, d);
		l_seen = lit_l * mix(light_params.z, 1.0, light);
	}
	// A remembered cell is full luminance (the post shader caps its density); it settles into the
	// live luminance while it turns into a seen cell.
	float l_out = mix(min(fade, 1.0), l_seen * fade, seen);

	vec2 wp = world_pos.xz;
	float n_coarse = vnoise(wp * look_params.x) * 2.0 - 1.0;
	float n_fine = vnoise(wp * look_params.x * 10.0) * 2.0 - 1.0;
	float t = look_params.y * (n_coarse + look_params.z * n_fine)
			+ look_params.w * clamp(world_pos.y / height_ref, 0.0, 1.0)
			+ mask.b * 0.45;

	float state = seen < 0.999 ? enc_memory(1.0 - seen) : enc_live(t);
	ALBEDO = vec3(enc_id(material_id), enc_l(l_out), state);
}
