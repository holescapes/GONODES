shader_type canvas_item;

// --- Animated Gradient Generator (No Input, Uses TIME) ---
// Tests TIME uniform binding in the MRT transpiler.

void fragment() {
	float t = TIME * 0.5;
	float r = sin(UV.x * 3.14159 + t) * 0.5 + 0.5;
	float g = cos(UV.y * 3.14159 + t * 1.3) * 0.5 + 0.5;
	float b = sin((UV.x + UV.y) * 2.0 - t * 0.7) * 0.5 + 0.5;

	gn_out0 = vec4(r, g, b, 1.0);            // Output 0: animated color
	gn_out1 = vec4(vec3(r), 1.0);            // Output 1: red channel only
	gn_out2 = vec4(vec3(g), 1.0);            // Output 2: green channel only
}
