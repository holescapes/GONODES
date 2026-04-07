shader_type canvas_item;
// CornerPinTOP — 4-point perspective warp using bilinear interpolation
// of UV coordinates defined by 4 corner positions.

uniform sampler2D source_tex : hint_default_white;
uniform vec2 top_left = vec2(0.0, 0.0);
uniform vec2 top_right = vec2(1.0, 0.0);
uniform vec2 bottom_left = vec2(0.0, 1.0);
uniform vec2 bottom_right = vec2(1.0, 1.0);
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);

float cross2d(vec2 a, vec2 b) {
	return a.x * b.y - a.y * b.x;
}

// Solve for UV given output position using inverse bilinear mapping
vec2 inverse_bilinear(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {
	vec2 e = b - a;
	vec2 f = d - a;
	vec2 g = a - b + c - d;
	vec2 h = p - a;

	float k2 = cross2d(g, f);
	float k1 = cross2d(e, f) + cross2d(h, g);
	float k0 = cross2d(h, e);

	// Degenerate case: k2 ≈ 0 → linear solve
	if (abs(k2) < 0.0001) {
		float v = -k0 / (k1 + 0.0001);
		float denom = e.x + g.x * v;
		float u = (abs(denom) > 0.0001) ? (h.x - f.x * v) / denom : (h.y - f.y * v) / (e.y + g.y * v + 0.0001);
		return vec2(u, v);
	}

	float w = k1 * k1 - 4.0 * k0 * k2;
	if (w < 0.0) return vec2(-1.0);

	w = sqrt(w);
	float v1 = (-k1 - w) / (2.0 * k2);
	float v2 = (-k1 + w) / (2.0 * k2);

	float v = (v1 >= 0.0 && v1 <= 1.0) ? v1 : v2;
	float denom = e.x + g.x * v;
	float u = (abs(denom) > 0.0001) ? (h.x - f.x * v) / denom : (h.y - f.y * v) / (e.y + g.y * v + 0.0001);

	return vec2(u, v);
}

void fragment() {
	vec2 uv = inverse_bilinear(UV, top_left, top_right, bottom_right, bottom_left);

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = bg_color;
	} else {
		COLOR = texture(source_tex, uv);
	}
}
