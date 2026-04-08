shader_type canvas_item;

// --- Threshold Matte (Input Required) ---
// 3 outputs from a single threshold: masked foreground, alpha matte, inverted matte.
// Tests uniform parameter binding in GLSLMulti.

uniform sampler2D gn_tex0 : hint_default_white;
uniform float threshold = 0.5;
uniform float softness = 0.1;

void fragment() {
	vec4 src = texture(gn_tex0, UV);
	float luma = dot(src.rgb, vec3(0.299, 0.587, 0.114));

	float matte = smoothstep(threshold - softness, threshold + softness, luma);

	gn_out0 = vec4(src.rgb * matte, matte);          // Output 0: masked foreground
	gn_out1 = vec4(vec3(matte), 1.0);                // Output 1: matte
	gn_out2 = vec4(vec3(1.0 - matte), 1.0);          // Output 2: inverted matte
}
