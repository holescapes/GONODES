shader_type canvas_item;

// --- Split to Luminance + Edges ---
uniform sampler2D gn_tex0 : hint_default_white;

void fragment() {
	vec4 src = texture(gn_tex0, UV);
	float luma = dot(src.rgb, vec3(0.299, 0.587, 0.114));

	gn_out0 = src;                             // Output 0: original
	gn_out1 = vec4(vec3(luma), src.a);        // Output 1: luminance
}
