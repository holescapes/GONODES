shader_type canvas_item;
// Pixelate / Mosaic effect
// Inspired by various Shadertoy pixelation shaders

uniform sampler2D gn_tex0 : hint_default_white;
uniform vec2 gn_resolution;
uniform float pixel_size = 8.0;  // Mosaic block size in pixels

void fragment() {
	float ps = max(pixel_size, 1.0);
	vec2 block = floor(FRAGCOORD.xy / ps) * ps + ps * 0.5;
	vec2 uv = block / gn_resolution;
	COLOR = texture(gn_tex0, uv);
}
