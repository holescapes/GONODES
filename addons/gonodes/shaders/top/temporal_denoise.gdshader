shader_type canvas_item;
// Temporal denoise — blends current frame with previous accumulated frame,
// rejecting pixels where motion/change exceeds a threshold.

uniform sampler2D source_tex : hint_default_black;
uniform sampler2D prev_tex : hint_default_black;
uniform float strength : hint_range(0.0, 1.0) = 0.8;
uniform float threshold : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	vec4 current = texture(source_tex, UV);
	vec4 previous = texture(prev_tex, UV);

	// Per-pixel difference for motion-aware rejection
	float diff = length(current.rgb - previous.rgb);

	// Smooth step rejection: high difference => use more of current frame
	float reject = smoothstep(threshold * 0.5, threshold, diff);

	// Blend weight: strength controls how much of previous to keep,
	// but reject overrides for areas with large changes (motion)
	float blend = strength * (1.0 - reject);

	vec4 result = mix(current, previous, blend);
	COLOR = vec4(result.rgb, current.a);
}
