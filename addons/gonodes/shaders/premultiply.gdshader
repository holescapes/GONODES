shader_type canvas_item;
// Premultiply / Unpremultiply alpha shader.

uniform sampler2D source_tex : hint_default_white;
uniform int mode : hint_range(0, 1) = 0;  // 0=Premultiply, 1=Unpremultiply

void fragment() {
	vec4 c = texture(source_tex, UV);

	if (mode == 0) {
		// Premultiply
		c.rgb *= c.a;
	} else {
		// Unpremultiply
		if (c.a > 0.0) {
			c.rgb /= c.a;
		}
	}

	COLOR = c;
}
