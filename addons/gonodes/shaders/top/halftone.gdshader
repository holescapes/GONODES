shader_type canvas_item;
// Halftone — CMYK or BW dot screen pattern.

uniform sampler2D source_tex : hint_default_white;
uniform float dot_size : hint_range(1.0, 50.0) = 8.0;
uniform int mode : hint_range(0, 1) = 0; // 0 = BW, 1 = CMYK
uniform float angle_c : hint_range(0.0, 90.0) = 15.0;
uniform float angle_m : hint_range(0.0, 90.0) = 75.0;
uniform float angle_y : hint_range(0.0, 90.0) = 0.0;
uniform float angle_k : hint_range(0.0, 90.0) = 45.0;

float halftone_dot(vec2 uv, float a, float size, float value) {
	float rad = radians(a);
	mat2 rot = mat2(vec2(cos(rad), -sin(rad)), vec2(sin(rad), cos(rad)));
	vec2 rotated = rot * uv;
	vec2 cell = fract(rotated / size) - 0.5;
	float radius = value * 0.707;
	return step(length(cell), radius);
}

void fragment() {
	vec2 pixel_uv = UV * vec2(textureSize(source_tex, 0));
	vec4 src = texture(source_tex, UV);

	if (mode == 0) {
		// BW halftone
		float luma = dot(src.rgb, vec3(0.2126, 0.7152, 0.0722));
		float dot_val = halftone_dot(pixel_uv, angle_k, dot_size, luma);
		COLOR = vec4(vec3(dot_val), src.a);
	} else {
		// CMYK halftone
		vec3 cmy = 1.0 - src.rgb;
		float k = min(cmy.r, min(cmy.g, cmy.b));
		vec3 cmy_pure = (cmy - k) / max(1.0 - k, 0.001);

		float c_dot = 1.0 - halftone_dot(pixel_uv, angle_c, dot_size, cmy_pure.r);
		float m_dot = 1.0 - halftone_dot(pixel_uv, angle_m, dot_size, cmy_pure.g);
		float y_dot = 1.0 - halftone_dot(pixel_uv, angle_y, dot_size, cmy_pure.b);
		float k_dot = 1.0 - halftone_dot(pixel_uv, angle_k, dot_size, k);

		vec3 result = vec3(c_dot * m_dot * y_dot * k_dot);
		COLOR = vec4(result, src.a);
	}
}
