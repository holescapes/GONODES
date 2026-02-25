shader_type canvas_item;
// SDF rectangle generator for RectangleTOP.

uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 center = vec2(0.5, 0.5);
uniform vec2 rect_size = vec2(0.6, 0.4);
uniform float corner_radius : hint_range(0.0, 0.5) = 0.0;
uniform float border_width = 0.0;
uniform float softness : hint_range(0.0, 0.1) = 0.005;

float sdf_rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 uv = UV - center;
	float dist = sdf_rounded_box(uv, rect_size * 0.5, corner_radius);

	float shape;
	if (border_width > 0.0) {
		float outer = smoothstep(softness, -softness, dist);
		float inner = smoothstep(softness, -softness, dist + border_width);
		shape = outer - inner;
	} else {
		shape = smoothstep(softness, -softness, dist);
	}

	COLOR = mix(bg_color, fill_color, shape);
}
