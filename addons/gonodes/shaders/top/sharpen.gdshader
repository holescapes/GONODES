shader_type canvas_item;
// SharpenTOP — unsharp mask sharpening filter.
// 8-tap (cross + diagonal) neighbourhood for high-quality edge detection.

uniform sampler2D source_tex : hint_default_white;
uniform float strength : hint_range(0.0, 10.0) = 1.0;
uniform float radius : hint_range(0.1, 10.0) = 1.0;

void fragment() {
	vec2 texel = vec2(1.0) / vec2(textureSize(source_tex, 0));
	vec2 s = texel * radius;

	vec4 center = texture(source_tex, UV);

	// 8 neighbours: cross (weight 2) + diagonals (weight 1)
	vec4 n  = texture(source_tex, UV + vec2(   0.0, -s.y));
	vec4 s_ = texture(source_tex, UV + vec2(   0.0,  s.y));
	vec4 w  = texture(source_tex, UV + vec2( -s.x,   0.0));
	vec4 e  = texture(source_tex, UV + vec2(  s.x,   0.0));
	vec4 nw = texture(source_tex, UV + vec2( -s.x, -s.y));
	vec4 ne = texture(source_tex, UV + vec2(  s.x, -s.y));
	vec4 sw = texture(source_tex, UV + vec2( -s.x,  s.y));
	vec4 se = texture(source_tex, UV + vec2(  s.x,  s.y));

	// Weighted average: cross neighbours count double
	vec4 blurred = (n + s_ + w + e) * 2.0 + (nw + ne + sw + se);
	blurred /= 12.0;

	// Unsharp mask: original + strength * (original - blurred)
	vec4 sharpened = center + (center - blurred) * strength;

	COLOR = clamp(sharpened, vec4(0.0), vec4(1.0));
}
