shader_type canvas_item;
// Z-Composite: merges two renders based on their depth buffers.
// Outputs the pixel from whichever render is closer to the camera.

uniform sampler2D color_a : hint_default_white;
uniform sampler2D depth_a : hint_default_white;
uniform sampler2D color_b : hint_default_black;
uniform sampler2D depth_b : hint_default_white;
uniform int compare_mode = 0; // 0=Nearer, 1=Farther
uniform float bias : hint_range(-0.01, 0.01) = 0.0;

void fragment() {
	vec4 ca = texture(color_a, UV);
	vec4 cb = texture(color_b, UV);
	float da = texture(depth_a, UV).r;
	float db = texture(depth_b, UV).r;

	// Depth textures: lower value = closer to camera (standard convention)
	bool use_a;
	if (compare_mode == 0) {
		use_a = (da + bias) <= db;  // Nearer
	} else {
		use_a = (da - bias) >= db;  // Farther
	}
	COLOR = use_a ? ca : cb;
}
