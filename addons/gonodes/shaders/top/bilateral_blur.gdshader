shader_type canvas_item;
// Bilateral blur — edge-preserving smoothing.
// Weights samples by both spatial distance and intensity difference.

uniform sampler2D source_tex : hint_default_white;
uniform int radius : hint_range(1, 10) = 3;
uniform float sigma_spatial : hint_range(0.1, 20.0) = 3.0;
uniform float sigma_range : hint_range(0.01, 1.0) = 0.1;

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(source_tex, 0));
	vec3 center_col = texture(source_tex, UV).rgb;

	vec3 sum = vec3(0.0);
	float weight_sum = 0.0;

	for (int dy = -radius; dy <= radius; dy++) {
		for (int dx = -radius; dx <= radius; dx++) {
			vec2 offset = vec2(float(dx), float(dy)) * texel;
			vec3 sample_col = texture(source_tex, UV + offset).rgb;

			// Spatial weight
			float spatial_dist = length(vec2(float(dx), float(dy)));
			float ws = exp(-spatial_dist * spatial_dist / (2.0 * sigma_spatial * sigma_spatial));

			// Range weight (intensity similarity)
			vec3 diff = sample_col - center_col;
			float range_dist = dot(diff, diff);
			float wr = exp(-range_dist / (2.0 * sigma_range * sigma_range));

			float w = ws * wr;
			sum += sample_col * w;
			weight_sum += w;
		}
	}

	COLOR = vec4(sum / weight_sum, texture(source_tex, UV).a);
}
