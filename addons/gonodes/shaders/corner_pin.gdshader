shader_type canvas_item;
// CornerPinTOP — 4-point perspective warp using bilinear interpolation
// of UV coordinates defined by 4 corner positions.

uniform sampler2D source_tex : hint_default_white;
uniform vec2 top_left = vec2(0.0, 0.0);
uniform vec2 top_right = vec2(1.0, 0.0);
uniform vec2 bottom_left = vec2(0.0, 1.0);
uniform vec2 bottom_right = vec2(1.0, 1.0);
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);

// Solve for UV given output position using inverse bilinear mapping
vec2 inverse_bilinear(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {
	vec2 e = b - a;
	vec2 f = d - a;
	vec2 g = a - b + c - d;
	vec2 h = p - a;

	float k2 = cross(vec2(g.x, g.y), vec2(f.x, f.y));
	float k1 = cross(vec2(e.x, e.y), vec2(f.x, f.y)) + cross(vec2(h.x, h.y), vec2(g.x, g.y));
	float k0 = cross(vec2(h.x, h.y), vec2(e.x, e.y));

	float w = k1 * k1 - 4.0 * k0 * k2;
	if (w < 0.0) return vec2(-1.0);

	w = sqrt(w);
	float v1 = (-k1 - w) / (2.0 * k2);
	float v2 = (-k1 + w) / (2.0 * k2);

	float v = (v1 >= 0.0 && v1 <= 1.0) ? v1 : v2;
	float u = (h.x - f.x * v) / (e.x + g.x * v);

	if (abs(e.x + g.x * v) < 0.0001) {
		u = (h.y - f.y * v) / (e.y + g.y * v);
	}

	return vec2(u, v);
}

float cross(vec2 a, vec2 b) {
	return a.x * b.y - a.y * b.x;
}

void fragment() {
	vec2 uv = inverse_bilinear(UV, top_left, top_right, bottom_right, bottom_left);

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = bg_color;
	} else {
		COLOR = texture(source_tex, uv);
	}
}
