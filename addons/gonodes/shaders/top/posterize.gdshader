shader_type canvas_item;
// Posterize shader — reduces color to N discrete levels spanning [0, 1].

uniform sampler2D source_tex : hint_default_white;
uniform int levels : hint_range(2, 256) = 4;

void fragment() {
	vec4 c = texture(source_tex, UV);
	float l = float(levels) - 1.0;
	c.rgb = floor(c.rgb * l + 0.5) / l;
	COLOR = c;
}
