shader_type canvas_item;
// Posterize shader — reduces color levels.

uniform sampler2D source_tex : hint_default_white;
uniform int levels : hint_range(2, 256) = 4;

void fragment() {
	vec4 c = texture(source_tex, UV);
	float l = float(levels);
	c.rgb = floor(c.rgb * l) / l;
	COLOR = c;
}
