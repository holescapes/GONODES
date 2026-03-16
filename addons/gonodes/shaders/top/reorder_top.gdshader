shader_type canvas_item;

uniform sampler2D source_tex : hint_default_white;
uniform int output_r : hint_range(0, 6) = 0;
uniform int output_g : hint_range(0, 6) = 1;
uniform int output_b : hint_range(0, 6) = 2;
uniform int output_a : hint_range(0, 6) = 3;

float get_channel(vec4 c, int ch) {
	if (ch == 0) return c.r;       // Red
	if (ch == 1) return c.g;       // Green
	if (ch == 2) return c.b;       // Blue
	if (ch == 3) return c.a;       // Alpha
	if (ch == 4) return 1.0;       // One
	if (ch == 5) return 0.0;       // Zero
	// Luminance
	return dot(c.rgb, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec4 src = texture(source_tex, UV);
	COLOR = vec4(
		get_channel(src, output_r),
		get_channel(src, output_g),
		get_channel(src, output_b),
		get_channel(src, output_a)
	);
}
