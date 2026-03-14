shader_type canvas_item;
// Bezier mesh warp — bicubic Bezier surface deformation.
// Uses a 4x4 grid of control points for smooth curved warping.
// Control points are passed as uniforms (16 vec2 values).

uniform vec2 cp00 = vec2(0.0, 0.0);
uniform vec2 cp10 = vec2(0.333, 0.0);
uniform vec2 cp20 = vec2(0.667, 0.0);
uniform vec2 cp30 = vec2(1.0, 0.0);
uniform vec2 cp01 = vec2(0.0, 0.333);
uniform vec2 cp11 = vec2(0.333, 0.333);
uniform vec2 cp21 = vec2(0.667, 0.333);
uniform vec2 cp31 = vec2(1.0, 0.333);
uniform vec2 cp02 = vec2(0.0, 0.667);
uniform vec2 cp12 = vec2(0.333, 0.667);
uniform vec2 cp22 = vec2(0.667, 0.667);
uniform vec2 cp32 = vec2(1.0, 0.667);
uniform vec2 cp03 = vec2(0.0, 1.0);
uniform vec2 cp13 = vec2(0.333, 1.0);
uniform vec2 cp23 = vec2(0.667, 1.0);
uniform vec2 cp33 = vec2(1.0, 1.0);
uniform sampler2D input_tex : filter_linear;

// Cubic Bernstein basis functions
float B0(float t) { return (1.0 - t) * (1.0 - t) * (1.0 - t); }
float B1(float t) { return 3.0 * t * (1.0 - t) * (1.0 - t); }
float B2(float t) { return 3.0 * t * t * (1.0 - t); }
float B3(float t) { return t * t * t; }

// Evaluate bicubic Bezier surface at parameter (u, v) → output position
vec2 bezier_surface(float u, float v) {
	// Rows (in v direction)
	vec2 row0 = B0(u) * cp00 + B1(u) * cp10 + B2(u) * cp20 + B3(u) * cp30;
	vec2 row1 = B0(u) * cp01 + B1(u) * cp11 + B2(u) * cp21 + B3(u) * cp31;
	vec2 row2 = B0(u) * cp02 + B1(u) * cp12 + B2(u) * cp22 + B3(u) * cp32;
	vec2 row3 = B0(u) * cp03 + B1(u) * cp13 + B2(u) * cp23 + B3(u) * cp33;

	return B0(v) * row0 + B1(v) * row1 + B2(v) * row2 + B3(v) * row3;
}

void fragment() {
	// We need the inverse mapping: from output pixel → source UV.
	// For a Bezier surface there's no closed-form inverse, so we use
	// Newton-Raphson iteration to find (u, v) such that bezier_surface(u, v) ≈ UV.

	vec2 target = UV;
	vec2 uv_guess = UV; // Start with identity as initial guess

	for (int i = 0; i < 8; i++) {
		vec2 pos = bezier_surface(uv_guess.x, uv_guess.y);
		vec2 err = pos - target;

		if (length(err) < 0.0001) break;

		// Compute Jacobian via finite differences
		float eps = 0.001;
		vec2 du = (bezier_surface(uv_guess.x + eps, uv_guess.y) - pos) / eps;
		vec2 dv = (bezier_surface(uv_guess.x, uv_guess.y + eps) - pos) / eps;

		float det = du.x * dv.y - du.y * dv.x;
		if (abs(det) < 1e-8) break;

		// Inverse Jacobian * error
		vec2 delta;
		delta.x = (dv.y * err.x - dv.x * err.y) / det;
		delta.y = (-du.y * err.x + du.x * err.y) / det;

		uv_guess -= delta;
	}

	if (uv_guess.x < -0.01 || uv_guess.x > 1.01 || uv_guess.y < -0.01 || uv_guess.y > 1.01) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(input_tex, clamp(uv_guess, vec2(0.0), vec2(1.0)));
	}
}
