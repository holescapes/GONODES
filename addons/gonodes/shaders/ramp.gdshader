shader_type canvas_item;
// Gradient ramp generator for RampTOP.
// Generates linear, radial, or circular ramps.

uniform int ramp_type = 0; // 0=horizontal, 1=vertical, 2=radial, 3=circular (angular)
uniform vec4 color_a : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 center = vec2(0.5, 0.5);
uniform float phase = 0.0;
uniform bool repeat_enabled = false;

void fragment() {
	float t = 0.0;

	switch (ramp_type) {
		case 0: // Horizontal
			t = UV.x;
			break;
		case 1: // Vertical
			t = UV.y;
			break;
		case 2: // Radial
			t = length(UV - center) * 2.0;
			break;
		case 3: // Circular (angular)
			vec2 d = UV - center;
			t = atan(d.y, d.x) / (2.0 * PI) + 0.5;
			break;
	}

	t = t + phase;

	if (repeat_enabled) {
		t = fract(t);
	} else {
		t = clamp(t, 0.0, 1.0);
	}

	COLOR = mix(color_a, color_b, t);
}
