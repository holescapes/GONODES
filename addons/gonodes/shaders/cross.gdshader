shader_type canvas_item;
// Crossfade shader for CrossTOP.
// Simple linear interpolation between two textures.

uniform sampler2D texture_a : hint_default_white;
uniform sampler2D texture_b : hint_default_black;
uniform float cross_value : hint_range(0.0, 1.0) = 0.5; // 0=A, 1=B

void fragment() {
	vec4 a = texture(texture_a, UV);
	vec4 b = texture(texture_b, UV);
	COLOR = mix(a, b, cross_value);
}
