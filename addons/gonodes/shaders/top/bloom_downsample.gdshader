shader_type canvas_item;
// Dual Kawase downsample — 5 bilinear taps at half-texel offsets.
// Each pass halves the resolution, spreading the blur cheaply.

uniform sampler2D source_tex : hint_default_white;
uniform vec2 texel_size = vec2(1.0 / 512.0, 1.0 / 512.0);

void fragment() {
	vec2 uv = UV;
	vec2 half_texel = texel_size * 0.5;

	vec4 sum = texture(source_tex, uv) * 4.0;
	sum += texture(source_tex, uv + vec2(-half_texel.x, -half_texel.y));
	sum += texture(source_tex, uv + vec2( half_texel.x, -half_texel.y));
	sum += texture(source_tex, uv + vec2(-half_texel.x,  half_texel.y));
	sum += texture(source_tex, uv + vec2( half_texel.x,  half_texel.y));

	COLOR = sum / 8.0;
}
