shader_type canvas_item;
// Standalone Depth-of-Field post-process.
// Takes a colour texture and a depth texture, computes circle of confusion
// per pixel, then applies a variable-radius disc blur.

uniform sampler2D color_tex : hint_default_white;
uniform sampler2D depth_tex : hint_default_white;
uniform float focal_distance : hint_range(0.0, 1.0) = 0.5;
uniform float focal_range : hint_range(0.001, 1.0) = 0.1;
uniform float max_blur : hint_range(0.0, 20.0) = 8.0;
uniform float bokeh_brightness : hint_range(1.0, 4.0) = 1.2;
uniform int quality = 1; // 0=Low(4), 1=Medium(8), 2=High(16)

void fragment() {
	vec2 tex_size = vec2(textureSize(color_tex, 0));
	vec2 pixel = 1.0 / tex_size;

	float depth = texture(depth_tex, UV).r;
	float coc = clamp(abs(depth - focal_distance) - focal_range, 0.0, 1.0);
	float blur_radius = coc * max_blur;

	if (blur_radius < 0.5) {
		COLOR = texture(color_tex, UV);
	} else {
		// Disc blur with golden-angle sampling
		int num_samples;
		if (quality == 0) {
			num_samples = 4;
		} else if (quality == 2) {
			num_samples = 16;
		} else {
			num_samples = 8;
		}
		float golden_angle = 2.39996323;  // radians
		vec4 acc = vec4(0.0);
		float total_weight = 0.0;

		for (int i = 0; i < num_samples; i++) {
			float r = sqrt(float(i) + 0.5) / sqrt(float(num_samples));
			float theta = float(i) * golden_angle;
			vec2 offset = vec2(cos(theta), sin(theta)) * r * blur_radius * pixel;
			vec4 sample_col = texture(color_tex, UV + offset);
			// Bokeh brightness boost: brighter samples weigh more
			float w = 1.0 + (sample_col.r + sample_col.g + sample_col.b) * (bokeh_brightness - 1.0);
			acc += sample_col * w;
			total_weight += w;
		}

		COLOR = acc / total_weight;
	}
}
