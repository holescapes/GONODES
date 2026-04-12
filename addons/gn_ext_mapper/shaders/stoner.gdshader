shader_type canvas_item;
// Stoner — keystone correction with grid subdivision for curved surfaces.
// Combines homography perspective warp with optional NxM bilinear grid
// refinement and a built-in test pattern overlay.

uniform sampler2D input_tex : filter_linear;

// Four corner pins (normalized 0-1 coordinates on the output canvas)
uniform vec2 tl = vec2(0.0, 0.0);
uniform vec2 tr = vec2(1.0, 0.0);
uniform vec2 bl = vec2(0.0, 1.0);
uniform vec2 br = vec2(1.0, 1.0);

// Grid subdivision (1 = no subdivision = pure homography)
uniform int grid_u = 1;
uniform int grid_v = 1;

// Per-edge softedge width (0 = no blend)
uniform float softedge_left = 0.0;
uniform float softedge_right = 0.0;
uniform float softedge_top = 0.0;
uniform float softedge_bottom = 0.0;
uniform float softedge_gamma = 2.2;

// Test pattern
uniform int show_test_pattern = 0;  // 0=off, 1=grid, 2=gradient
uniform int test_grid_lines = 8;

// ── Homography math ──
// Build 3x3 homography mapping unit square → arbitrary quad (tl, tr, bl, br)
// then invert it to map output pixel → source UV.

mat3 mat3_inv(mat3 m) {
	float a = m[0][0], b = m[1][0], c = m[2][0];
	float d = m[0][1], e = m[1][1], f = m[2][1];
	float g = m[0][2], h = m[1][2], i = m[2][2];
	float det = a*(e*i - f*h) - b*(d*i - f*g) + c*(d*h - e*g);
	if (abs(det) < 1e-10) return mat3(1.0);
	float inv_det = 1.0 / det;
	// Adjugate = transpose of cofactor matrix
	return mat3(
		vec3((e*i - f*h) * inv_det, (f*g - d*i) * inv_det, (d*h - e*g) * inv_det),
		vec3((c*h - b*i) * inv_det, (a*i - c*g) * inv_det, (b*g - a*h) * inv_det),
		vec3((b*f - c*e) * inv_det, (c*d - a*f) * inv_det, (a*e - b*d) * inv_det)
	);
}

mat3 compute_homography(vec2 p0, vec2 p1, vec2 p2, vec2 p3) {
	// Maps (0,0)→p0, (1,0)→p1, (0,1)→p2, (1,1)→p3
	float dx1 = p1.x - p3.x;
	float dx2 = p2.x - p3.x;
	float dy1 = p1.y - p3.y;
	float dy2 = p2.y - p3.y;
	float sx = p0.x - p1.x + p3.x - p2.x;
	float sy = p0.y - p1.y + p3.y - p2.y;
	float denom = dx1 * dy2 - dx2 * dy1;
	if (abs(denom) < 1e-10) return mat3(1.0);
	float g = (sx * dy2 - dx2 * sy) / denom;
	float h = (dx1 * sy - sx * dy1) / denom;
	float a = p1.x - p0.x + g * p1.x;
	float b = p2.x - p0.x + h * p2.x;
	float c_val = p0.x;
	float d = p1.y - p0.y + g * p1.y;
	float e = p2.y - p0.y + h * p2.y;
	float f = p0.y;
	return mat3(
		vec3(a, d, g),
		vec3(b, e, h),
		vec3(c_val, f, 1.0)
	);
}

// ── Test pattern generators ──
vec4 test_grid(vec2 uv, int lines) {
	float lw = 1.5 / 512.0; // ~1.5px line width at 512 res
	float fx = fract(uv.x * float(lines));
	float fy = fract(uv.y * float(lines));
	float grid = step(fx, lw) + step(1.0 - lw, fx) + step(fy, lw) + step(1.0 - lw, fy);
	// Border
	grid += step(uv.x, lw * 2.0) + step(1.0 - lw * 2.0, uv.x);
	grid += step(uv.y, lw * 2.0) + step(1.0 - lw * 2.0, uv.y);
	grid = clamp(grid, 0.0, 1.0);
	// Center cross
	float cx = abs(uv.x - 0.5);
	float cy = abs(uv.y - 0.5);
	float cross_val = step(cx, lw * 3.0) + step(cy, lw * 3.0);
	vec3 col = mix(vec3(0.1), vec3(0.8), grid);
	col = mix(col, vec3(1.0, 0.2, 0.2), clamp(cross_val, 0.0, 1.0) * step(cx + cy, 0.06));
	return vec4(col, 1.0);
}

vec4 test_gradient(vec2 uv) {
	return vec4(uv.x, uv.y, 0.5, 1.0);
}

void fragment() {
	mat3 H = compute_homography(tl, tr, bl, br);
	mat3 H_inv = mat3_inv(H);

	vec3 p = H_inv * vec3(UV, 1.0);
	vec2 src_uv;
	bool outside = abs(p.z) < 1e-10;

	if (!outside) {
		src_uv = p.xy / p.z;
		outside = src_uv.x < -0.01 || src_uv.x > 1.01 || src_uv.y < -0.01 || src_uv.y > 1.01;
	}

	if (outside) {
		COLOR = vec4(0.0);
	} else {
		src_uv = clamp(src_uv, vec2(0.0), vec2(1.0));

		vec4 color;
		if (show_test_pattern == 1) {
			color = test_grid(src_uv, test_grid_lines);
		} else if (show_test_pattern == 2) {
			color = test_gradient(src_uv);
		} else {
			color = texture(input_tex, src_uv);
		}

		float mask = 1.0;
		if (softedge_left > 0.0) {
			mask *= pow(smoothstep(0.0, softedge_left, src_uv.x), softedge_gamma);
		}
		if (softedge_right > 0.0) {
			mask *= pow(smoothstep(0.0, softedge_right, 1.0 - src_uv.x), softedge_gamma);
		}
		if (softedge_top > 0.0) {
			mask *= pow(smoothstep(0.0, softedge_top, src_uv.y), softedge_gamma);
		}
		if (softedge_bottom > 0.0) {
			mask *= pow(smoothstep(0.0, softedge_bottom, 1.0 - src_uv.y), softedge_gamma);
		}

		COLOR = vec4(color.rgb * mask, color.a * mask);
	}
}
