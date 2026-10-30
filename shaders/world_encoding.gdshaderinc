// Data encoding shared by the world shader (writes it) and the ascii post shader (reads it).
// The world is rendered unshaded into the 3D buffer; each pixel carries data, not colour:
//   R = material id        G = luminance 0..1        B = state
// Measured on the dev machine (GL compatibility, NVIDIA): ALBEDO is written raw (no sRGB curve),
// but values below ~0.2 come back up to 5/255 too low. Every channel therefore starts at 0.2 or
// above, and the clear colour (0, 0, 0) decodes as "void" (id 0).
// State: below 0.475 = visible, 0.2..0.45 carries the palette offset t (noise, height, glint);
// 0.5..1.0 = remembered, (state - 0.5) * 2 = how much memory is left (1 = fully remembered,
// falling to 0 while a remembered cell turns into a seen one).

const float ENC_ID_BASE = 0.25;
const float ENC_ID_STEP = 0.045;
const float ENC_L_BASE = 0.2;
const float ENC_L_RANGE = 0.8;
const float ENC_LIVE_BASE = 0.2;
const float ENC_LIVE_RANGE = 0.25;
const float ENC_MEMORY_THRESHOLD = 0.475;
const float ENC_T_MIN = -0.3;
const float ENC_T_MAX = 1.0;

float enc_id(int id) {
	return ENC_ID_BASE + float(id) * ENC_ID_STEP;
}

float enc_l(float l) {
	return ENC_L_BASE + ENC_L_RANGE * clamp(l, 0.0, 1.0);
}

float enc_live(float t) {
	return ENC_LIVE_BASE + ENC_LIVE_RANGE * clamp((t - ENC_T_MIN) / (ENC_T_MAX - ENC_T_MIN), 0.0, 1.0);
}

float enc_memory(float memory_left) {
	return 0.5 + 0.5 * clamp(memory_left, 0.0, 1.0);
}

int dec_id(float r) {
	if (r < ENC_ID_BASE - 0.5 * ENC_ID_STEP) {
		return 0;
	}
	return int(floor((r - ENC_ID_BASE) / ENC_ID_STEP + 0.5));
}

float dec_l(float g) {
	return clamp((g - ENC_L_BASE) / ENC_L_RANGE, 0.0, 1.0);
}

bool dec_is_memory(float b) {
	return b >= ENC_MEMORY_THRESHOLD;
}

float dec_memory_left(float b) {
	return clamp((b - 0.5) * 2.0, 0.0, 1.0);
}

float dec_t(float b) {
	float k = clamp((b - ENC_LIVE_BASE) / ENC_LIVE_RANGE, 0.0, 1.0);
	return ENC_T_MIN + k * (ENC_T_MAX - ENC_T_MIN);
}

// Static value noise: a pure function of position (and, for flow, of time). Never per-frame random.
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
