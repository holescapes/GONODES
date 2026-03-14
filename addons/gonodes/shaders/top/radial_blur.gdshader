shader_type canvas_item;
// Radial (zoom) blur shader — samples along line from UV toward center.

uniform sampler2D source_tex : hint_default_white;
uniform float strength : hint_range(0.0, 1.0) = 0.1;
uniform int samples : hint_range(4, 64) = 16;
uniform float center_x : hint_range(0.0, 1.0) = 0.5;
uniform float center_y : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 center = vec2(center_x, center_y);
	vec2 dir = UV - center;
	float dist = length(dir);

	vec4 color = vec4(0.0);
	float total_weight = 0.0;
	float inv_samples = 1.0 / float(samples);

	for (int i = 0; i < samples; i++) {
		float t = float(i) * inv_samples;
		float weight = 1.0 - t * 0.5;  // Linear falloff weight
		vec2 offset = dir * t * strength;
		color += texture(source_tex, UV - offset) * weight;
		total_weight += weight;
	}

	COLOR = color / total_weight;
}
