shader_type canvas_item;
// SharpenTOP — unsharp mask sharpening filter.

uniform sampler2D source_tex : hint_default_white;
uniform float strength = 1.0;
uniform float radius = 1.0;

void fragment() {
	vec2 texel = vec2(1.0) / vec2(textureSize(source_tex, 0));
	vec2 step = texel * radius;

	// Sample center and 4 neighbours (cross pattern)
	vec4 center = texture(source_tex, UV);
	vec4 top    = texture(source_tex, UV + vec2(0.0, -step.y));
	vec4 bottom = texture(source_tex, UV + vec2(0.0,  step.y));
	vec4 left   = texture(source_tex, UV + vec2(-step.x, 0.0));
	vec4 right  = texture(source_tex, UV + vec2( step.x, 0.0));

	// Unsharp mask: original + strength * (original - blurred)
	vec4 blurred = (top + bottom + left + right) * 0.25;
	vec4 sharpened = center + (center - blurred) * strength;

	COLOR = clamp(sharpened, vec4(0.0), vec4(1.0));
}
