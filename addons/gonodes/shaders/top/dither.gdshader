shader_type canvas_item;
// Ordered (Bayer) dither shader.

uniform sampler2D source_tex : hint_default_white;
uniform int levels : hint_range(2, 256) = 2;
uniform int matrix_size : hint_range(0, 2) = 1; // 0=2x2, 1=4x4, 2=8x8
uniform float spread : hint_range(0.0, 1.0) = 0.5;
uniform bool color_dither = false;

// 4x4 Bayer matrix (normalized 0-1)
const float bayer4[16] = float[16](
	 0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
	12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
	 3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
	15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
);

// 2x2 Bayer
const float bayer2[4] = float[4](0.0/4.0, 2.0/4.0, 3.0/4.0, 1.0/4.0);

float get_bayer(ivec2 coord) {
	if (matrix_size == 0) {
		int idx = (coord.y % 2) * 2 + (coord.x % 2);
		return bayer2[idx];
	} else if (matrix_size == 1) {
		int idx = (coord.y % 4) * 4 + (coord.x % 4);
		return bayer4[idx];
	} else {
		// 8x8 via recursive 4x4
		int x4 = coord.x % 4;
		int y4 = coord.y % 4;
		int idx = y4 * 4 + x4;
		float base = bayer4[idx];
		int x2 = (coord.x / 4) % 2;
		int y2 = (coord.y / 4) % 2;
		int idx2 = y2 * 2 + x2;
		return (base + bayer2[idx2]) / 4.0 + 0.125;
	}
}

void fragment() {
	vec4 src = texture(source_tex, UV);
	ivec2 coord = ivec2(UV * vec2(textureSize(source_tex, 0)));
	float threshold = get_bayer(coord) - 0.5;
	float n = float(levels) - 1.0;

	vec3 result;
	if (color_dither) {
		result = floor(src.rgb * n + 0.5 + threshold * spread) / n;
	} else {
		float luma = dot(src.rgb, vec3(0.2126, 0.7152, 0.0722));
		float dithered = floor(luma * n + 0.5 + threshold * spread) / n;
		result = vec3(dithered);
	}
	result = clamp(result, vec3(0.0), vec3(1.0));
	COLOR = vec4(result, src.a);
}
