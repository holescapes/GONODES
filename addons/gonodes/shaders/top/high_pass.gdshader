shader_type canvas_item;
// High-pass filter — extracts high-frequency detail (original minus blur).
// Uses a built-in box blur approximation.

uniform sampler2D source_tex : hint_default_white;
uniform float radius : hint_range(1.0, 50.0) = 5.0;
uniform float strength : hint_range(0.0, 5.0) = 1.0;
uniform float offset : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(source_tex, 0));
	int r = int(radius);

	// Simple box blur
	vec3 sum = vec3(0.0);
	float count = 0.0;
	for (int dy = -r; dy <= r; dy++) {
		for (int dx = -r; dx <= r; dx++) {
			sum += texture(source_tex, UV + vec2(float(dx), float(dy)) * texel).rgb;
			count += 1.0;
		}
	}
	vec3 blurred = sum / count;
	vec3 original = texture(source_tex, UV).rgb;

	// High pass = original - blur + offset
	vec3 high_pass = (original - blurred) * strength + vec3(offset);
	high_pass = clamp(high_pass, vec3(0.0), vec3(1.0));

	COLOR = vec4(high_pass, texture(source_tex, UV).a);
}
