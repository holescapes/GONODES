shader_type canvas_item;
// ConvolutionTOP — custom NxN kernel convolution (3x3, 5x5, 7x7).

uniform sampler2D source_tex : hint_default_white;
uniform float kernel[49]; // max 7x7 = 49 values
uniform int kernel_size : hint_range(3, 7) = 3; // must be odd: 3, 5, or 7
uniform float divisor = 1.0;
uniform float bias = 0.0;

void fragment() {
	vec2 texel = vec2(1.0) / vec2(textureSize(source_tex, 0));
	int half_k = kernel_size / 2;
	vec4 result = vec4(0.0);

	for (int y = -half_k; y <= half_k; y++) {
		for (int x = -half_k; x <= half_k; x++) {
			int ki = (y + half_k) * kernel_size + (x + half_k);
			vec2 uv = UV + vec2(float(x), float(y)) * texel;
			result += texture(source_tex, uv) * kernel[ki];
		}
	}

	result = result / divisor + bias;
	COLOR = clamp(result, vec4(0.0), vec4(1.0));
}
