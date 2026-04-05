shader_type canvas_item;
// Bloom compositing shader — blends blurred glow with the original image.
// Used by BloomTOP for the final compositing pass.

uniform sampler2D original_tex : hint_default_white;
uniform sampler2D glow_tex : hint_default_black;
uniform float intensity : hint_range(0.0, 5.0) = 1.0;
uniform int blend_mode : hint_range(0, 2) = 0; // 0=Screen, 1=Add, 2=Soft Light

void fragment() {
	vec4 original = texture(original_tex, UV);
	vec4 glow = texture(glow_tex, UV) * intensity;

	vec4 result;
	if (blend_mode == 1) {
		// Additive
		result = vec4(original.rgb + glow.rgb, original.a);
	} else if (blend_mode == 2) {
		// Soft Light
		vec3 a = original.rgb;
		vec3 b = glow.rgb;
		result = vec4(mix(a, 1.0 - 2.0 * (1.0 - a) * (1.0 - b), step(0.5, b)), original.a);
	} else {
		// Screen (default): 1 - (1-a)*(1-b)
		result = vec4(1.0 - (1.0 - original.rgb) * (1.0 - glow.rgb), original.a);
	}

	COLOR = result;
}
