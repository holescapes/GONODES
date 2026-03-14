shader_type canvas_item;
// Levels / color correction shader for LevelTOP.
// Applies brightness, contrast, gamma, invert, and opacity to input texture.

uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform float contrast : hint_range(0.0, 4.0) = 1.0;
uniform float gamma : hint_range(0.01, 4.0) = 1.0;
uniform bool invert = false;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	// Apply brightness (multiply)
	vec3 rgb = col.rgb * brightness;

	// Apply contrast (around 0.5 midpoint)
	rgb = (rgb - 0.5) * contrast + 0.5;

	// Apply gamma
	rgb = pow(max(rgb, vec3(0.0)), vec3(1.0 / gamma));

	// Apply invert
	if (invert) {
		rgb = 1.0 - rgb;
	}

	// Apply opacity
	rgb = clamp(rgb, vec3(0.0), vec3(1.0));
	COLOR = vec4(rgb, col.a * opacity);
}
