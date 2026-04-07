shader_type canvas_item;
// Kaleidoscope — N-fold angular mirror symmetry.

uniform sampler2D source_tex : hint_default_white;
uniform int segments : hint_range(2, 32) = 6;
uniform float rotation : hint_range(0.0, 360.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	vec2 uv = UV - center;

	// Rotate
	float rot = radians(rotation);
	float cs = cos(rot);
	float sn = sin(rot);
	uv = vec2(uv.x * cs - uv.y * sn, uv.x * sn + uv.y * cs);

	// Convert to polar
	float angle_val = atan(uv.y, uv.x);
	float dist = length(uv);

	// Kaleidoscope fold
	float seg_angle = 2.0 * 3.14159265 / float(segments);
	angle_val = mod(angle_val, seg_angle);
	// Mirror alternate segments
	if (angle_val > seg_angle * 0.5) {
		angle_val = seg_angle - angle_val;
	}

	// Back to cartesian
	vec2 new_uv = vec2(cos(angle_val), sin(angle_val)) * dist + center;
	new_uv = clamp(new_uv, vec2(0.0), vec2(1.0));

	COLOR = texture(source_tex, new_uv);
}
