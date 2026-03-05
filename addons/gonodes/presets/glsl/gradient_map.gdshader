// Gradient map — remap input luminance to a two-color gradient
// uniform vec4 color_dark : source_color = vec4(0.0, 0.0, 0.2, 1.0);
// uniform vec4 color_bright : source_color = vec4(1.0, 0.8, 0.2, 1.0);
// uniform float contrast : hint_range(0.1, 5.0) = 1.5;

void fragment() {
	vec4 tex = texture(gn_tex0, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	// Apply contrast curve
	luma = clamp((luma - 0.5) * contrast + 0.5, 0.0, 1.0);
	vec3 mapped = mix(color_dark.rgb, color_bright.rgb, luma);
	COLOR = vec4(mapped, tex.a);
}
