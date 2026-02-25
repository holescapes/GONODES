shader_type canvas_item;
// Gaussian blur shader for BlurTOP.
// Two-pass separable blur using a single shader with direction uniform.
// Run once with direction=(1,0) then direction=(0,1) for full 2D blur.

uniform sampler2D source_tex : hint_default_white;
uniform vec2 direction = vec2(1.0, 0.0); // (1,0) for horizontal, (0,1) for vertical
uniform float blur_size : hint_range(0.0, 100.0) = 5.0;
uniform int quality : hint_range(1, 8) = 4; // number of taps per side

void fragment() {
	vec2 tex_size = vec2(textureSize(source_tex, 0));
	vec2 pixel_step = direction / tex_size * blur_size;

	vec4 color = texture(source_tex, UV);
	float total_weight = 1.0;

	for (int i = 1; i <= quality; i++) {
		float fi = float(i);
		// Gaussian-like weight falloff
		float weight = exp(-0.5 * (fi * fi) / max(float(quality) * 0.5, 0.5));
		color += texture(source_tex, UV + pixel_step * fi) * weight;
		color += texture(source_tex, UV - pixel_step * fi) * weight;
		total_weight += weight * 2.0;
	}

	COLOR = color / total_weight;
}
