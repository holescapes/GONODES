shader_type canvas_item;

// --- UV Gradient Generator (No Input) ---
// Single output showing UV coordinates. Minimal generator test.

void fragment() {
	gn_out0 = vec4(UV.x, UV.y, 0.5, 1.0);
}
