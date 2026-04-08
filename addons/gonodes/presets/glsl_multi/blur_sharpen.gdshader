shader_type canvas_item;

// --- Blur + Sharpen (Input Required) ---
// 3 outputs: original, box-blurred, sharpened via unsharp mask.
// Tests gn_tex0 input binding + multiple outputs from same input.

uniform sampler2D gn_tex0 : hint_default_white;
uniform float blur_radius = 2.0;

void fragment() {
	vec2 px = 1.0 / vec2(textureSize(gn_tex0, 0));
	vec4 src = texture(gn_tex0, UV);

	// Simple 5-tap box blur
	vec4 blurred = src * 0.2;
	blurred += texture(gn_tex0, UV + vec2( blur_radius, 0.0) * px) * 0.2;
	blurred += texture(gn_tex0, UV + vec2(-blur_radius, 0.0) * px) * 0.2;
	blurred += texture(gn_tex0, UV + vec2(0.0,  blur_radius) * px) * 0.2;
	blurred += texture(gn_tex0, UV + vec2(0.0, -blur_radius) * px) * 0.2;

	// Unsharp mask: original + (original - blurred)
	vec4 sharpened = src + (src - blurred) * 2.0;
	sharpened = clamp(sharpened, 0.0, 1.0);

	gn_out0 = src;       // Output 0: original
	gn_out1 = blurred;   // Output 1: blurred
	gn_out2 = sharpened; // Output 2: sharpened
}
