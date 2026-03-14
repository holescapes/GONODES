shader_type canvas_item;
// Quad warp — homography-based 4-corner pin perspective transform.
// Maps input texture through a perspective matrix derived from 4 corner points.

uniform vec2 corner_tl = vec2(0.0, 0.0);
uniform vec2 corner_tr = vec2(1.0, 0.0);
uniform vec2 corner_bl = vec2(0.0, 1.0);
uniform vec2 corner_br = vec2(1.0, 1.0);
uniform sampler2D input_tex : filter_linear;

// Compute homography matrix from unit square to arbitrary quad.
// Uses the direct linear transform (DLT) approach.
mat3 compute_homography(vec2 tl, vec2 tr, vec2 bl, vec2 br) {
	float dx1 = tr.x - br.x;
	float dx2 = bl.x - br.x;
	float dy1 = tr.y - br.y;
	float dy2 = bl.y - br.y;
	float sx = tl.x - tr.x + br.x - bl.x;
	float sy = tl.y - tr.y + br.y - bl.y;
	float det = dx1 * dy2 - dx2 * dy1;

	if (abs(det) < 1e-8) {
		return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0));
	}

	float g = (sx * dy2 - dx2 * sy) / det;
	float h = (dx1 * sy - sx * dy1) / det;
	float a = tr.x - tl.x + g * tr.x;
	float b = bl.x - tl.x + h * bl.x;
	float c = tl.x;
	float d = tr.y - tl.y + g * tr.y;
	float e = bl.y - tl.y + h * bl.y;
	float f = tl.y;

	return mat3(
		vec3(a, d, g),
		vec3(b, e, h),
		vec3(c, f, 1.0)
	);
}

void fragment() {
	// Compute inverse homography: map from output (warped) coords to input (source) coords
	mat3 H = compute_homography(corner_tl, corner_tr, corner_bl, corner_br);

	// Invert the homography
	float det_h = H[0][0] * (H[1][1] * H[2][2] - H[1][2] * H[2][1])
				- H[0][1] * (H[1][0] * H[2][2] - H[1][2] * H[2][0])
				+ H[0][2] * (H[1][0] * H[2][1] - H[1][1] * H[2][0]);

	if (abs(det_h) < 1e-8) {
		COLOR = vec4(0.0);
		return;
	}

	mat3 H_inv;
	H_inv[0][0] = (H[1][1] * H[2][2] - H[1][2] * H[2][1]) / det_h;
	H_inv[0][1] = (H[0][2] * H[2][1] - H[0][1] * H[2][2]) / det_h;
	H_inv[0][2] = (H[0][1] * H[1][2] - H[0][2] * H[1][1]) / det_h;
	H_inv[1][0] = (H[1][2] * H[2][0] - H[1][0] * H[2][2]) / det_h;
	H_inv[1][1] = (H[0][0] * H[2][2] - H[0][2] * H[2][0]) / det_h;
	H_inv[1][2] = (H[0][2] * H[1][0] - H[0][0] * H[1][2]) / det_h;
	H_inv[2][0] = (H[1][0] * H[2][1] - H[1][1] * H[2][0]) / det_h;
	H_inv[2][1] = (H[0][1] * H[2][0] - H[0][0] * H[2][1]) / det_h;
	H_inv[2][2] = (H[0][0] * H[1][1] - H[0][1] * H[1][0]) / det_h;

	vec3 src = H_inv * vec3(UV, 1.0);
	vec2 src_uv = src.xy / src.z;

	if (src_uv.x < 0.0 || src_uv.x > 1.0 || src_uv.y < 0.0 || src_uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(input_tex, src_uv);
	}
}
