shader_type canvas_item;
// Pixelate / mosaic — snaps UV to a grid, producing blocky pixels.

uniform sampler2D source_tex : hint_default_white;
uniform float pixel_size : hint_range(1.0, 256.0) = 8.0;

void fragment() {
	vec2 tex_size = vec2(textureSize(source_tex, 0));
	vec2 grid = max(vec2(pixel_size), vec2(1.0));
	vec2 snapped = (floor(UV * tex_size / grid) + 0.5) * grid / tex_size;
	COLOR = texture(source_tex, snapped);
}
