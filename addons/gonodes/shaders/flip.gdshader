shader_type canvas_item;
// Flip/mirror shader for FlipTOP.

uniform sampler2D source_tex : hint_default_white;
uniform bool flip_x = false;
uniform bool flip_y = false;

void fragment() {
	vec2 uv = UV;
	if (flip_x) uv.x = 1.0 - uv.x;
	if (flip_y) uv.y = 1.0 - uv.y;
	COLOR = texture(source_tex, uv);
}
