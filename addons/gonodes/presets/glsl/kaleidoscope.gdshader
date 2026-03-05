// Kaleidoscope — mirror UV coordinates into symmetric sectors
// uniform int segments : hint_range(2, 16) = 6;
// uniform float rotation : hint_range(0.0, 6.2831) = 0.0;

void fragment() {
	vec2 uv = UV - 0.5;
	float angle = atan(uv.y, uv.x) + rotation + gn_time * 0.2;
	float radius = length(uv);

	float seg_angle = TAU / float(segments);
	angle = mod(angle, seg_angle);
	// Mirror alternating sectors
	if (mod(floor(angle / seg_angle + 0.5), 2.0) > 0.5) {
		angle = seg_angle - angle;
	}

	vec2 mirrored = vec2(cos(angle), sin(angle)) * radius + 0.5;
	COLOR = texture(gn_tex0, mirrored);
}
