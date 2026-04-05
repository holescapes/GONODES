shader_type canvas_item;
// Blur shader for BlurTOP.
// Two-pass separable blur using a single shader with direction uniform.
// Run once with direction=(1,0) then direction=(0,1) for full 2D blur.
// Methods: 0=Gaussian, 1=Box, 2=Triangle, 3=Sinc, 4=Hanning, 5=Blackman, 6=Bump.

uniform sampler2D source_tex : hint_default_white;
uniform vec2 direction = vec2(1.0, 0.0);
uniform float blur_size : hint_range(0.0, 100.0) = 5.0;
uniform int quality : hint_range(1, 16) = 4;
uniform int method : hint_range(0, 6) = 0;

const float PI = 3.14159265358979;

float compute_weight(float norm, int m) {
	if (m == 1) {
		return 1.0; // Box: uniform
	} else if (m == 2) {
		return 1.0 - norm; // Triangle (Bartlett): linear falloff
	} else if (m == 3) {
		// Sinc: sin(pi*x)/(pi*x)
		float x = norm * PI;
		return (norm < 0.001) ? 1.0 : sin(x) / x;
	} else if (m == 4) {
		// Hanning (raised cosine)
		return 0.5 + 0.5 * cos(PI * norm);
	} else if (m == 5) {
		// Blackman window
		return 0.42 + 0.5 * cos(PI * norm) + 0.08 * cos(2.0 * PI * norm);
	} else if (m == 6) {
		// Bump: inverted Gaussian — heavier at edges
		return 1.0 - exp(-3.0 * norm * norm);
	}
	// Default: Gaussian
	return exp(-3.0 * norm * norm);
}

void fragment() {
	vec2 tex_size = vec2(textureSize(source_tex, 0));
	vec2 pixel_step = direction / tex_size * (blur_size / float(quality));

	vec4 color = texture(source_tex, UV);
	float total_weight = 1.0;

	for (int i = 1; i <= quality; i++) {
		float fi = float(i);
		float norm = fi / float(quality);
		float weight = compute_weight(norm, method);
		color += texture(source_tex, UV + pixel_step * fi) * weight;
		color += texture(source_tex, UV - pixel_step * fi) * weight;
		total_weight += weight * 2.0;
	}

	COLOR = color / total_weight;
}
