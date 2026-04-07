shader_type canvas_item;
// Crossfade blend for SwitchTOP "Blend Between" mode.

uniform sampler2D texture_a : hint_default_black;
uniform sampler2D texture_b : hint_default_black;
uniform float blend_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 a = texture(texture_a, UV);
	vec4 b = texture(texture_b, UV);
	COLOR = mix(a, b, blend_amount);
}
