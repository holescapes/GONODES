shader_type canvas_item;
// ISF-style Kaleidoscope generator — radial symmetry pattern.

uniform vec2 isf_rendersize;
uniform float segments = 6.0;
uniform float rotation = 0.0;
uniform float zoom = 1.0;
uniform vec4 color_a = vec4(0.1, 0.4, 0.8, 1.0);
uniform vec4 color_b = vec4(0.9, 0.2, 0.5, 1.0);
uniform vec4 color_c = vec4(0.1, 0.8, 0.3, 1.0);

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float angle = atan(uv.y, uv.x) + rotation + TIME * 0.2;
	float radius = length(uv) * zoom;

	// Create kaleidoscope mirror
	float seg_angle = 3.14159265 * 2.0 / segments;
	angle = mod(angle, seg_angle);
	if (angle > seg_angle * 0.5)
		angle = seg_angle - angle;

	// Create pattern
	float p1 = sin(angle * 3.0 + radius * 5.0 + TIME) * 0.5 + 0.5;
	float p2 = cos(radius * 4.0 - TIME * 0.7) * 0.5 + 0.5;
	float p3 = sin(angle * 5.0 - radius * 3.0 + TIME * 1.3) * 0.5 + 0.5;

	vec4 col = color_a * p1 + color_b * p2 + color_c * p3;
	col /= max(p1 + p2 + p3, 0.001);
	col.a = 1.0;
	COLOR = col;
}
