// Plasma — classic demoscene swirling colorful plasma

void fragment() {
	vec2 uv = UV * 10.0;
	float t = gn_time * 0.5;

	float v = sin(uv.x + t);
	v += sin(uv.y + t * 0.7);
	v += sin((uv.x + uv.y) * 0.5 + t * 1.3);
	v += sin(length(uv - 5.0) + t);
	v *= 0.25;

	vec3 col;
	col.r = sin(v * PI + 0.0) * 0.5 + 0.5;
	col.g = sin(v * PI + 2.094) * 0.5 + 0.5;
	col.b = sin(v * PI + 4.188) * 0.5 + 0.5;

	COLOR = vec4(col, 1.0);
}
