shader_type canvas_item;

// --- RGB Channel Splitter ---
// Splits input into separate R, G, B channels + original
uniform sampler2D gn_tex0 : hint_default_white;

void fragment() {
	vec4 src = texture(gn_tex0, UV);

	gn_out0 = src;                             // Output 0: original
	gn_out1 = vec4(src.r, 0.0, 0.0, src.a);  // Output 1: red channel
	gn_out2 = vec4(0.0, src.g, 0.0, src.a);  // Output 2: green channel
	gn_out3 = vec4(0.0, 0.0, src.b, src.a);  // Output 3: blue channel
}
