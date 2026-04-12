shader_type canvas_item;
// Quad warp — homography-based 4-corner pin perspective transform.
// Maps input texture through a perspective matrix derived from 4 corner points.

uniform vec2 tl = vec2(0.0, 0.0);
uniform vec2 tr = vec2(1.0, 0.0);
uniform vec2 bl = vec2(0.0, 1.0);
uniform vec2 br = vec2(1.0, 1.0);
uniform sampler2D input_tex : filter_linear;

// Compute homography matrix from unit square to arbitrary quad.
// Uses the direct linear transform (DLT) approach.
mat3 compute_homography(vec2 p0, vec2 p1, vec2 p2, vec2 p3) {
	float dx1 = p1.x - p3.x;
	float dx2 = p2.x - p3.x;
	float dy1 = p1.y - p3.y;
	float dy2 = p2.y - p3.y;
	float sx = p0.x - p1.x + p3.x - p2.x;
	float sy = p0.y - p1.y + p3.y - p2.y;
	float det = dx1 * dy2 - dx2 * dy1;

	if (abs(det) < 1e-8) {
		return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0));
	}

	float g = (sx * dy2 - dx2 * sy) / det;
	float h = (dx1 * sy - sx * dy1) / det;
	float a = p1.x - p0.x + g * p1.x;
	float b = p2.x - p0.x + h * p2.x;
	float c = p0.x;
	float d = p1.y - p0.y + g * p1.y;
	float e = p2.y - p0.y + h * p2.y;
	float f = p0.y;

	return mat3(
		vec3(a, d, g),
		vec3(b, e, h),
		vec3(c, f, 1.0)
	);
}

void fragment() {
	mat3 H = compute_homography(tl, tr, bl, br);

	float det_h = H[0][0] * (H[1][1] * H[2][2] - H[1][2] * H[2][1])
				- H[0][1] * (H[1][0] * H[2][2] - H[1][2] * H[2][0])
				+ H[0][2] * (H[1][0] * H[2][1] - H[1][1] * H[2][0]);

	mat3 H_inv;
	bool valid = abs(det_h) > 1e-8;

	if (valid) {
		H_inv[0][0] = (H[1][1] * H[2][2] - H[1][2] * H[2][1]) / det_h;
		H_inv[0][1] = (H[0][2] * H[2][1] - H[0][1] * H[2][2]) / det_h;
		H_inv[0][2] = (H[0][1] * H[1][2] - H[0][2] * H[1][1]) / det_h;
		H_inv[1][0] = (H[1][2] * H[2][0] - H[1][0] * H[2][2]) / det_h;
		H_inv[1][1] = (H[0][0] * H[2][2] - H[0][2] * H[2][0]) / det_h;
		H_inv[1][2] = (H[0][2] * H[1][0] - H[0][0] * H[1][2]) / det_h;
		H_inv[2][0] = (H[1][0] * H[2][1] - H[1][1] * H[2][0]) / det_h;
		H_inv[2][1] = (H[0][1] * H[2][0] - H[0][0] * H[2][1]) / det_h;
		H_inv[2][2] = (H[0][0] * H[1][1] - H[0][1] * H[1][0]) / det_h;
	} else {
		H_inv = mat3(1.0);
	}

	vec3 src = H_inv * vec3(UV, 1.0);
	vec2 src_uv = src.xy / src.z;

	if (!valid || src_uv.x < 0.0 || src_uv.x > 1.0 || src_uv.y < 0.0 || src_uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(input_tex, src_uv);
	}
}
