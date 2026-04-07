shader_type canvas_item;
// Median filter — 3x3 or 5x5 sorting network to remove noise.

uniform sampler2D source_tex : hint_default_white;
uniform int radius : hint_range(0, 1) = 0; // 0 = 3x3, 1 = 5x5

// Swap helper for sorting network
void mn(inout float a, inout float b) {
	float t = min(a, b);
	b = max(a, b);
	a = t;
}

// 9-element sorting network → returns median (index 4)
float median9(float v0, float v1, float v2, float v3, float v4,
			  float v5, float v6, float v7, float v8) {
	mn(v0, v1); mn(v3, v4); mn(v6, v7);
	mn(v1, v2); mn(v4, v5); mn(v7, v8);
	mn(v0, v1); mn(v3, v4); mn(v6, v7);
	mn(v0, v3); mn(v3, v6); mn(v0, v3);
	mn(v2, v5); mn(v5, v8); mn(v2, v5);
	mn(v2, v8);
	mn(v1, v4); mn(v4, v7); mn(v1, v4);
	mn(v1, v7);
	mn(v4, v2); mn(v2, v4);
	return v4;
}

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(source_tex, 0));

	if (radius == 0) {
		// 3x3 median per channel
		vec3 samples[9];
		int idx = 0;
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				samples[idx] = texture(source_tex, UV + vec2(float(dx), float(dy)) * texel).rgb;
				idx++;
			}
		}
		float r = median9(samples[0].r, samples[1].r, samples[2].r,
						   samples[3].r, samples[4].r, samples[5].r,
						   samples[6].r, samples[7].r, samples[8].r);
		float g = median9(samples[0].g, samples[1].g, samples[2].g,
						   samples[3].g, samples[4].g, samples[5].g,
						   samples[6].g, samples[7].g, samples[8].g);
		float b = median9(samples[0].b, samples[1].b, samples[2].b,
						   samples[3].b, samples[4].b, samples[5].b,
						   samples[6].b, samples[7].b, samples[8].b);
		COLOR = vec4(r, g, b, texture(source_tex, UV).a);
	} else {
		// 5x5 approximation: run 3x3 median twice (iterative approach)
		// First pass: gather 3x3 medians for the cross neighborhood
		vec3 medians[9];
		int m_idx = 0;
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				vec2 center = UV + vec2(float(dx), float(dy)) * texel;
				vec3 s[9];
				int si = 0;
				for (int ddy = -1; ddy <= 1; ddy++) {
					for (int ddx = -1; ddx <= 1; ddx++) {
						s[si] = texture(source_tex, center + vec2(float(ddx), float(ddy)) * texel).rgb;
						si++;
					}
				}
				medians[m_idx] = vec3(
					median9(s[0].r,s[1].r,s[2].r,s[3].r,s[4].r,s[5].r,s[6].r,s[7].r,s[8].r),
					median9(s[0].g,s[1].g,s[2].g,s[3].g,s[4].g,s[5].g,s[6].g,s[7].g,s[8].g),
					median9(s[0].b,s[1].b,s[2].b,s[3].b,s[4].b,s[5].b,s[6].b,s[7].b,s[8].b)
				);
				m_idx++;
			}
		}
		float r = median9(medians[0].r,medians[1].r,medians[2].r,medians[3].r,medians[4].r,
						   medians[5].r,medians[6].r,medians[7].r,medians[8].r);
		float g = median9(medians[0].g,medians[1].g,medians[2].g,medians[3].g,medians[4].g,
						   medians[5].g,medians[6].g,medians[7].g,medians[8].g);
		float b = median9(medians[0].b,medians[1].b,medians[2].b,medians[3].b,medians[4].b,
						   medians[5].b,medians[6].b,medians[7].b,medians[8].b);
		COLOR = vec4(r, g, b, texture(source_tex, UV).a);
	}
}
