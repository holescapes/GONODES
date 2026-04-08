shader_type canvas_item;
// Flow-field visualization via Line Integral Convolution (LIC).
// Input: 2-channel vector field (RG = XY, remapped from [0,1] to [-1,1]).
// Produces streaky, organic flow visualization with optional directional coloring.
// Color modes: 0 = Magnitude, 1 = Direction (HSV), 2 = LIC greyscale, 3 = LIC + Direction.

uniform sampler2D source_tex : hint_default_white;
uniform int num_steps : hint_range(4, 64) = 24;
uniform float step_size : hint_range(0.0005, 0.02) = 0.004;
uniform float noise_scale : hint_range(1.0, 200.0) = 80.0;
uniform int color_mode : hint_range(0, 3) = 3;
uniform float contrast : hint_range(0.5, 4.0) = 1.8;
uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float saturation : hint_range(0.0, 1.0) = 0.75;
uniform float speed_tint : hint_range(0.0, 4.0) = 1.5;

// -- Hash-based white noise (no separate texture needed) -------------------------
float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// -- Decode RG [0,1] → velocity [-1,1] -------------------------------------------
vec2 decode_vel(vec2 rg) {
	return (rg - 0.5) * 2.0;
}

// -- HSV → RGB --------------------------------------------------------------------
vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 tex_sz = vec2(textureSize(source_tex, 0));
	vec2 vel0 = decode_vel(texture(source_tex, UV).rg);
	float mag0 = length(vel0);
	float angle0 = atan(vel0.y, vel0.x); // -PI … PI

	// -- LIC: trace streamline forward + backward, accumulate noise ---------------
	float lic_sum = 0.0;
	float wt_sum = 0.0;
	vec2 pos;

	// Forward
	pos = UV;
	for (int i = 0; i < num_steps; i++) {
		float w = 1.0 - float(i) / float(num_steps);
		lic_sum += hash21(floor(pos * noise_scale * tex_sz)) * w;
		wt_sum += w;
		vec2 v = decode_vel(texture(source_tex, pos).rg);
		pos += v * step_size;
		pos = clamp(pos, vec2(0.001), vec2(0.999));
	}

	// Backward
	pos = UV;
	for (int i = 0; i < num_steps; i++) {
		float w = 1.0 - float(i) / float(num_steps);
		lic_sum += hash21(floor(pos * noise_scale * tex_sz)) * w;
		wt_sum += w;
		vec2 v = decode_vel(texture(source_tex, pos).rg);
		pos -= v * step_size;
		pos = clamp(pos, vec2(0.001), vec2(0.999));
	}

	float lic = lic_sum / max(wt_sum, 1.0);
	// Contrast / brightness tweak
	lic = clamp(pow(lic, 1.0 / contrast) * brightness, 0.0, 1.0);

	// -- Color mapping ------------------------------------------------------------
	float hue = angle0 / 6.28318 + 0.5; // [0,1]
	float speed = min(mag0 * speed_tint, 1.0);
	vec3 col;

	if (color_mode == 0) {
		// Magnitude: black → white
		col = vec3(speed);
	} else if (color_mode == 1) {
		// Direction: HSV wheel, value from magnitude
		col = hsv2rgb(vec3(hue, saturation, 0.3 + speed * 0.7));
	} else if (color_mode == 2) {
		// LIC only: greyscale streamlines
		col = vec3(lic);
	} else {
		// LIC + Direction: colored streamlines (matches reference image)
		col = hsv2rgb(vec3(hue, saturation, lic * (0.4 + speed * 0.6)));
	}

	COLOR = vec4(col, 1.0);
}
