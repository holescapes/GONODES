shader_type canvas_item;
// Threshold shader for ThresholdTOP.
// Converts to binary black/white based on luminance threshold.

uniform sampler2D source_tex : hint_default_white;
uniform float threshold_val : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.0, 0.5) = 0.0; // 0 = hard, >0 = soft edge
uniform bool use_alpha = false; // threshold alpha instead of luminance

float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec4 col = texture(source_tex, UV);
	float val;

	if (use_alpha) {
		val = col.a;
	} else {
		val = luminance(col.rgb);
	}

	float result;
	if (softness > 0.0) {
		result = smoothstep(threshold_val - softness, threshold_val + softness, val);
	} else {
		result = step(threshold_val, val);
	}

	COLOR = vec4(vec3(result), 1.0);
}
