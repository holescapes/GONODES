shader_type canvas_item;
// TriangleTOP — draw 2D primitives: triangles, lines, or polygons.
// This generates the primitives procedurally via SDF.

uniform int shape_type : hint_range(0, 2) = 0; // 0=Triangle, 1=Line, 2=Pentagon
uniform vec4 fill_color : source_color = vec4(1.0);
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float size = 0.4;
uniform float border_width = 0.02;
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rotation = 0.0;
uniform float softness = 0.005;

float sdf_triangle(vec2 p, float r) {
	float k = sqrt(3.0);
	p.x = abs(p.x) - r;
	p.y = p.y + r / k;
	if (p.x + k * p.y > 0.0) p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
	p.x -= clamp(p.x, -2.0 * r, 0.0);
	return -length(p) * sign(p.y);
}

float sdf_line(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - w;
}

float sdf_pentagon(vec2 p, float r) {
	vec3 k = vec3(0.809016994, 0.587785252, 0.726542528);
	p.x = abs(p.x);
	p -= 2.0 * min(dot(vec2(-k.x, k.y), p), 0.0) * vec2(-k.x, k.y);
	p -= 2.0 * min(dot(vec2(k.x, k.y), p), 0.0) * vec2(k.x, k.y);
	p -= vec2(clamp(p.x, -r * k.z, r * k.z), r);
	return length(p) * sign(p.y);
}

void fragment() {
	vec2 p = UV - 0.5;
	float c = cos(rotation);
	float s = sin(rotation);
	p = vec2(p.x * c - p.y * s, p.x * s + p.y * c);

	float d;
	if (shape_type == 0) {
		d = sdf_triangle(p, size);
	} else if (shape_type == 1) {
		d = sdf_line(p, vec2(-size, 0.0), vec2(size, 0.0), 0.02);
	} else {
		d = sdf_pentagon(p, size);
	}

	float fill = 1.0 - smoothstep(-softness, softness, d);
	float border = 1.0 - smoothstep(border_width - softness, border_width + softness, abs(d));

	vec4 col = mix(bg_color, fill_color, fill);
	col = mix(col, border_color, border * step(0.001, border_width));
	COLOR = col;
}
