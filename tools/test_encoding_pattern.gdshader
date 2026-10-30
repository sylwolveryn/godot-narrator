shader_type spatial;
render_mode unshaded;
// Test pattern for tools/test_encoding.gd: writes known id / luminance / state values through the
// real encoding functions of world_encoding.gdshaderinc.
#include "res://shaders/world_encoding.gdshaderinc"

uniform int material_id = 1;
uniform float lum = 0.5;
// 0 = live state with palette offset `value`, 1 = memory with memory-left `value`.
uniform int state_mode = 0;
uniform float value = 0.0;

void fragment() {
	float state = state_mode == 0 ? enc_live(value) : enc_memory(value);
	ALBEDO = vec3(enc_id(material_id), enc_l(lum), state);
}
