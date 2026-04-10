shader_type canvas_item;
// Temporal motion blur using optical flow / motion vectors.
// Samples along the flow direction to create motion streaks.

uniform sampler2D color_tex : hint_default_white;
uniform sampler2D flow_tex : hint_default_black;  // RG = motion vectors
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform int num_samples = 8;  // 4, 8, 16

void fragment() {
	vec2 flow = texture(flow_tex, UV).rg;
	// Flow is typically in -0.5..0.5 range; scale by strength
	vec2 velocity = (flow - 0.5) * 2.0 * strength;

	vec4 acc = vec4(0.0);
	float total = 0.0;

	for (int i = 0; i < num_samples; i++) {
		float t = (float(i) / float(num_samples - 1)) - 0.5; // -0.5 to 0.5
		vec2 sample_uv = clamp(UV + velocity * t, vec2(0.0), vec2(1.0));
		acc += texture(color_tex, sample_uv);
		total += 1.0;
	}

	COLOR = acc / total;
}
