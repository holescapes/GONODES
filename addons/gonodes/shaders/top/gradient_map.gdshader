shader_type canvas_item;
// Gradient map — maps image luminance to a color gradient.

uniform sampler2D source_tex : hint_default_white;
uniform sampler2D gradient_tex : hint_default_white;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 src = texture(source_tex, UV);
	float luma = dot(src.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec4 mapped = texture(gradient_tex, vec2(luma, 0.5));
	COLOR = vec4(mix(src.rgb, mapped.rgb, intensity), src.a);
}
