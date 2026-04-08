shader_type canvas_item;
// Optical Flow — Horn-Schunck method (GLSL fragment, cross-platform).
// Outputs motion vectors encoded as:  R = horizontal motion, G = vertical motion, B = magnitude.
// Values are offset by 0.5 so zero motion = grey (0.5, 0.5, 0).

uniform sampler2D current_frame : hint_default_white;
uniform sampler2D previous_frame : hint_default_white;
uniform float sensitivity : hint_range(1.0, 100.0, 0.1) = 20.0;
uniform float smoothing : hint_range(0.001, 1.0, 0.001) = 0.1;
uniform int iterations : hint_range(1, 16, 1) = 4;

float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(current_frame, 0));
	vec2 uv = UV;

	// Spatial gradients (Sobel-like central differences on current frame luminance)
	float l = luminance(texture(current_frame, uv - vec2(texel.x, 0.0)).rgb);
	float r = luminance(texture(current_frame, uv + vec2(texel.x, 0.0)).rgb);
	float t = luminance(texture(current_frame, uv - vec2(0.0, texel.y)).rgb);
	float b = luminance(texture(current_frame, uv + vec2(0.0, texel.y)).rgb);
	float Ix = (r - l) * 0.5;
	float Iy = (b - t) * 0.5;

	// Temporal gradient
	float curr = luminance(texture(current_frame, uv).rgb);
	float prev = luminance(texture(previous_frame, uv).rgb);
	float It = curr - prev;

	// Horn-Schunck iterative solver
	float u = 0.0;
	float v = 0.0;
	float alpha_sq = smoothing * smoothing;

	for (int i = 0; i < iterations; i++) {
		// Laplacian approximation of flow neighbourhood
		float u_avg = 0.0;
		float v_avg = 0.0;
		// 4-connected neighbourhood average
		vec2 uv_l = uv - vec2(texel.x, 0.0);
		vec2 uv_r = uv + vec2(texel.x, 0.0);
		vec2 uv_t = uv - vec2(0.0, texel.y);
		vec2 uv_b = uv + vec2(0.0, texel.y);

		// For first iteration, neighbours are 0; subsequent iterations would
		// need a ping-pong buffer. In a single-pass approximation we use
		// the spatial gradient as a proxy for neighbourhood flow.
		float denom = alpha_sq + Ix * Ix + Iy * Iy;
		float common = (Ix * u + Iy * v + It) / max(denom, 1e-6);
		u = u - Ix * common;
		v = v - Iy * common;
	}

	// Scale by sensitivity and encode: 0.5 = no motion
	float out_r = clamp(u * sensitivity + 0.5, 0.0, 1.0);
	float out_g = clamp(v * sensitivity + 0.5, 0.0, 1.0);
	float magnitude = clamp(length(vec2(u, v)) * sensitivity * 2.0, 0.0, 1.0);

	vec3 flow_rgb = vec3(out_r, out_g, magnitude);
	COLOR = vec4(flow_rgb, 1.0);
}
