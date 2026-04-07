shader_type canvas_item;
// Kuwahara filter — oil painting / painterly effect.
// Uses 4-quadrant variance-based region selection (isotropic variant).

uniform sampler2D source_tex : hint_default_white;
uniform int radius : hint_range(1, 12) = 4;

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(source_tex, 0));
	int r = radius;

	// Accumulate mean + variance for 4 quadrants
	vec3 mean[4];
	float var_val[4];

	for (int q = 0; q < 4; q++) {
		mean[q] = vec3(0.0);
		var_val[q] = 0.0;
	}

	for (int q = 0; q < 4; q++) {
		vec3 sum = vec3(0.0);
		vec3 sum_sq = vec3(0.0);
		float count = 0.0;

		int x0 = (q == 0 || q == 2) ? -r : 0;
		int x1 = (q == 0 || q == 2) ? 0 : r;
		int y0 = (q == 0 || q == 1) ? -r : 0;
		int y1 = (q == 0 || q == 1) ? 0 : r;

		for (int dy = y0; dy <= y1; dy++) {
			for (int dx = x0; dx <= x1; dx++) {
				vec3 s = texture(source_tex, UV + vec2(float(dx), float(dy)) * texel).rgb;
				sum += s;
				sum_sq += s * s;
				count += 1.0;
			}
		}

		mean[q] = sum / count;
		vec3 variance = sum_sq / count - mean[q] * mean[q];
		var_val[q] = dot(variance, vec3(1.0));
	}

	// Pick quadrant with minimum variance
	int best = 0;
	float best_var = var_val[0];
	for (int q = 1; q < 4; q++) {
		if (var_val[q] < best_var) {
			best_var = var_val[q];
			best = q;
		}
	}

	COLOR = vec4(mean[best], texture(source_tex, UV).a);
}
