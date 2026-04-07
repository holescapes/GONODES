shader_type canvas_item;
// Frame difference shader for FrameDifferenceTOP.
// Subtracts current from previous frame to produce motion delta.

uniform sampler2D source_tex : hint_default_white;
uniform sampler2D prev_tex : hint_default_black;
uniform int mode = 0; // 0 = absolute, 1 = signed (offset to mid-gray)
uniform float gain = 1.0;
uniform float threshold = 0.0;

void fragment() {
	vec4 current = texture(source_tex, UV);
	vec4 prev = texture(prev_tex, UV);
	vec3 diff = current.rgb - prev.rgb;

	if (mode == 0) {
		// Absolute difference
		diff = abs(diff) * gain;
	} else {
		// Signed: offset so zero-difference sits at 0.5 gray
		diff = diff * gain * 0.5 + 0.5;
	}

	// Threshold: suppress small differences (noise gate)
	float mag = dot(abs(current.rgb - prev.rgb), vec3(0.333));
	float mask = smoothstep(threshold, threshold + 0.02, mag);
	diff *= mask;

	COLOR = vec4(diff, current.a);
}
