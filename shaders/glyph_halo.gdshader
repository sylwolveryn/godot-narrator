// Static halos of the glyph world (task-033, ported from Spike A glyph_halo): soft additive glow billboards over items,
// spikes and corruption. ONE MultiMesh holds every halo (one draw call, no screen texture, no post-process). Per instance:
// transform origin = glow centre (x/z cell centre, y light height), scale = glow radius, COLOR.rgb * COLOR.a = colour *
// intensity, INSTANCE_CUSTOM = (cell x, cell y, breath phase, kind: 0 item, 1 spikes, 2 corruption).
// Reveal: the instance reads its cell in the global reveal mask in the vertex shader; hidden cells collapse the quad,
// remembered cells keep `memory` of the glow. Breath: slow sine per kind (no per-frame random); corruption slides
// between two hues. Depth: the quad is lifted towards the camera and depth-tested, so walls in front hide the glow.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

#include "res://shaders/glyph_halo.gdshaderinc"

global uniform sampler2D reveal_mask : filter_nearest;

const float TWO_PI = 6.2831853;
const float HIDDEN_BELOW = 0.004;

uniform float lift = 0.5;
uniform float memory = 0.0;                   // share of the glow kept on remembered cells
uniform float breath_period[3];
uniform float breath_amount[3];
uniform float pool[3];
uniform vec3 hue_a = vec3(0.55, 0.28, 1.0);   // corruption hues
uniform vec3 hue_b = vec3(1.0, 0.28, 0.75);

varying vec2 q;
varying vec3 hc;
varying flat float h_pool;
varying flat float h_pool_y;
varying flat float h_squash;

void vertex() {
	int kind = int(INSTANCE_CUSTOM.w + 0.5);
	vec4 m = texelFetch(reveal_mask, ivec2(INSTANCE_CUSTOM.xy + 0.5), 0);
	float k = min(m.r, 1.0) * mix(memory, 1.0, m.g);
	if (k < HIDDEN_BELOW) {
		POSITION = vec4(0.0, 0.0, 2.0, 1.0);
		q = vec2(0.0);
		hc = vec3(0.0);
		h_pool = 0.0;
		h_pool_y = 0.0;
		h_squash = 1.0;
	} else {
		vec3 c = MODEL_MATRIX[3].xyz;
		float size = length(MODEL_MATRIX[0].xyz);
		float wave = sin(TIME * TWO_PI / breath_period[kind] + INSTANCE_CUSTOM.z);
		float breath = 1.0 + breath_amount[kind] * wave;
		vec3 r = INV_VIEW_MATRIX[0].xyz;
		vec3 u = INV_VIEW_MATRIX[1].xyz;
		vec3 to_cam = INV_VIEW_MATRIX[2].xyz;
		size *= 1.0 + 0.5 * breath_amount[kind] * wave;
		vec3 pos = c + (r * VERTEX.x + u * VERTEX.y) * size + to_cam * lift;
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(pos, 1.0);
		q = VERTEX.xy;
		vec3 col = COLOR.rgb;
		if (kind == 2) {
			col = mix(hue_a, hue_b, 0.5 + 0.5 * sin(TIME * TWO_PI / breath_period[2] * 0.5 + INSTANCE_CUSTOM.z));
		}
		hc = col * COLOR.a * breath * k;
		h_pool = pool[kind];
		h_pool_y = -c.y * u.y / size;
		h_squash = abs(to_cam.y);
	}
}

void fragment() {
	float g = halo_shape(q, h_pool_y, h_squash, h_pool);
	ALBEDO = hc;
	ALPHA = g;
}
