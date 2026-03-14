shader_type canvas_item;
// AnalyzeTOP — compute per-pixel min/max/average/sum of the input texture.
// Uses a multi-pass reduction-style approach in a single fragment:
// reads NxN neighbourhood and outputs the statistic.

uniform sampler2D source_tex : hint_default_white;
uniform int mode : hint_range(0, 3) = 0; // 0=Min, 1=Max, 2=Average, 3=Sum
uniform int kernel_size : hint_range(1, 64) = 8;

void fragment() {
	vec2 tex_size = vec2(textureSize(source_tex, 0));
	vec2 texel = vec2(1.0) / tex_size;

	vec4 result;
	if (mode == 0) {
		result = vec4(1.0); // Min — start high
	} else {
		result = vec4(0.0); // Max/Average/Sum — start low
	}

	int half_k = kernel_size / 2;
	float sample_count = 0.0;

	for (int y = -half_k; y <= half_k; y++) {
		for (int x = -half_k; x <= half_k; x++) {
			vec2 uv = UV + vec2(float(x), float(y)) * texel;
			vec4 s = texture(source_tex, clamp(uv, vec2(0.0), vec2(1.0)));

			if (mode == 0) {
				result = min(result, s);
			} else if (mode == 1) {
				result = max(result, s);
			} else {
				result += s;
			}
			sample_count += 1.0;
		}
	}

	if (mode == 2) {
		result /= sample_count; // Average
	}
	// mode == 3 is Sum — leave accumulated

	COLOR = result;
}
