shader_type canvas_item;
// Dual Kawase upsample — 8 bilinear taps at texel offsets.
// Each pass doubles the resolution, blending the blur back up.

uniform sampler2D source_tex : hint_default_white;
uniform vec2 texel_size = vec2(0.001953125, 0.001953125);

void fragment() {
	vec2 uv = UV;
	vec2 ts = texel_size;

	vec4 sum = vec4(0.0);
	sum += texture(source_tex, uv + vec2(-ts.x,       0.0)) * 2.0;
	sum += texture(source_tex, uv + vec2( ts.x,       0.0)) * 2.0;
	sum += texture(source_tex, uv + vec2(      0.0, -ts.y)) * 2.0;
	sum += texture(source_tex, uv + vec2(      0.0,  ts.y)) * 2.0;
	sum += texture(source_tex, uv + vec2(-ts.x, -ts.y));
	sum += texture(source_tex, uv + vec2( ts.x, -ts.y));
	sum += texture(source_tex, uv + vec2(-ts.x,  ts.y));
	sum += texture(source_tex, uv + vec2( ts.x,  ts.y));

	COLOR = sum / 12.0;
}
