shader_type canvas_item;
// Emboss convolution filter.
// Applies an emboss kernel with configurable angle, strength, and height.

uniform sampler2D source_tex : filter_linear, repeat_disable;
uniform float strength : hint_range(0.0, 5.0) = 1.0;
uniform float angle : hint_range(0.0, 360.0) = 135.0;
uniform float height : hint_range(0.0, 2.0) = 0.5;

void fragment() {
	vec2 pixel = 1.0 / vec2(textureSize(source_tex, 0));
	float rad = radians(angle);
	vec2 dir = vec2(cos(rad), sin(rad));

	// Emboss kernel: sample in the light direction and opposite
	vec3 s1 = texture(source_tex, UV - dir * pixel).rgb;
	vec3 s2 = texture(source_tex, UV + dir * pixel).rgb;

	// Emboss = difference + mid gray
	vec3 emboss = (s2 - s1) * strength + vec3(height);

	COLOR = vec4(emboss, texture(source_tex, UV).a);
}
