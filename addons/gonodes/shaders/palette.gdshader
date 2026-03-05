shader_type canvas_item;
// Palette quantization shader — maps each pixel to the nearest palette color.

uniform sampler2D source_tex : hint_default_white;
uniform sampler2D palette_tex : hint_default_white;
uniform int palette_size : hint_range(2, 256) = 8;
uniform bool dither = false;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.5;

// 4x4 Bayer ordered dithering matrix (normalized 0-1)
float bayer4(vec2 pos) {
	int x = int(mod(pos.x, 4.0));
	int y = int(mod(pos.y, 4.0));
	int index = x + y * 4;
	// Inline Bayer 4x4 values
	int bayer[16] = int[](0,8,2,10, 12,4,14,6, 3,11,1,9, 15,7,13,5);
	return float(bayer[index]) / 16.0 - 0.5;
}

void fragment() {
	vec4 c = texture(source_tex, UV);
	vec3 color = c.rgb;

	// Apply ordered dithering before quantization
	if (dither) {
		vec2 pixel_pos = UV * vec2(textureSize(source_tex, 0));
		float noise = bayer4(pixel_pos) * dither_strength / float(palette_size);
		color += vec3(noise);
	}

	// Find nearest palette color by RGB distance
	float best_dist = 999999.0;
	vec3 best_color = color;
	int count = palette_size;

	for (int i = 0; i < count; i++) {
		float u = (float(i) + 0.5) / float(count);
		vec3 pal = texture(palette_tex, vec2(u, 0.5)).rgb;
		vec3 diff = color - pal;
		float d = dot(diff, diff);
		if (d < best_dist) {
			best_dist = d;
			best_color = pal;
		}
	}

	COLOR = vec4(best_color, c.a);
}
