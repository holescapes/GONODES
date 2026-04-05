shader_type canvas_item;
// Bloom threshold pass — extracts bright areas above the threshold.
// Outputs black for pixels below threshold, original color for pixels above.

uniform sampler2D source_tex : hint_default_white;
uniform float threshold : hint_range(0.0, 5.0) = 1.0;
uniform float knee : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	vec4 color = texture(source_tex, UV);
	float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
	// Soft knee: smooth transition around threshold
	float soft = clamp((luma - threshold + knee) / (2.0 * knee + 0.0001), 0.0, 1.0);
	float contrib = soft * soft;
	// Hard threshold with soft knee blend
	float factor = max(contrib, step(threshold, luma));
	COLOR = vec4(color.rgb * factor, color.a);
}
