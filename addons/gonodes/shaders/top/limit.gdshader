shader_type canvas_item;
// Clamp pixel RGBA values to a min/max range.

uniform sampler2D source_tex : hint_default_white;
uniform float min_r : hint_range(0.0, 1.0) = 0.0;
uniform float max_r : hint_range(0.0, 1.0) = 1.0;
uniform float min_g : hint_range(0.0, 1.0) = 0.0;
uniform float max_g : hint_range(0.0, 1.0) = 1.0;
uniform float min_b : hint_range(0.0, 1.0) = 0.0;
uniform float max_b : hint_range(0.0, 1.0) = 1.0;
uniform float min_a : hint_range(0.0, 1.0) = 0.0;
uniform float max_a : hint_range(0.0, 1.0) = 1.0;
uniform bool clamp_rgb = true;  // true = per-channel RGBA, false = luminance only
uniform float min_luma : hint_range(0.0, 1.0) = 0.0;
uniform float max_luma : hint_range(0.0, 1.0) = 1.0;

float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec4 col = texture(source_tex, UV);

	if (clamp_rgb) {
		col.r = clamp(col.r, min_r, max_r);
		col.g = clamp(col.g, min_g, max_g);
		col.b = clamp(col.b, min_b, max_b);
		col.a = clamp(col.a, min_a, max_a);
	} else {
		// Luminance mode: scale RGB so luminance fits within [min_luma, max_luma]
		float lum = luminance(col.rgb);
		if (lum > 0.0) {
			float clamped = clamp(lum, min_luma, max_luma);
			col.rgb *= clamped / lum;
		}
	}

	COLOR = col;
}
