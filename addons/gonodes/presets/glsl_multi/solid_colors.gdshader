shader_type canvas_item;

// --- Solid Color Generator (No Input) ---
// 4 outputs with constant colors. Simplest possible MRT test.

void fragment() {
	gn_out0 = vec4(1.0, 0.0, 0.0, 1.0);  // Output 0: red
	gn_out1 = vec4(0.0, 1.0, 0.0, 1.0);  // Output 1: green
	gn_out2 = vec4(0.0, 0.0, 1.0, 1.0);  // Output 2: blue
	gn_out3 = vec4(1.0, 1.0, 0.0, 1.0);  // Output 3: yellow
}
