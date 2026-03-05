// Voronoi cells — animated cellular pattern
// uniform float cell_scale : hint_range(1.0, 20.0) = 6.0;

void fragment() {
	vec2 uv = UV * cell_scale;
	float t = gn_time * 0.3;

	float min_dist = 1.0;
	vec2 min_point = vec2(0.0);

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 cell = floor(uv) + neighbor;
			// Animated cell center
			vec2 point = vec2(
				fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453),
				fract(sin(dot(cell, vec2(269.5, 183.3))) * 43758.5453));
			point = 0.5 + 0.5 * sin(t + 6.2831 * point);
			vec2 diff = neighbor + point - fract(uv);
			float dist = length(diff);
			if (dist < min_dist) {
				min_dist = dist;
				min_point = point;
			}
		}
	}

	vec3 col = vec3(min_point.x, min_point.y, 1.0 - min_dist);
	col *= 1.0 - 0.4 * min_dist;
	COLOR = vec4(col, 1.0);
}
