shader_type canvas_item;
// Voronoi / Worley noise generator.

uniform float scale : hint_range(1.0, 100.0) = 10.0;
uniform float jitter : hint_range(0.0, 1.0) = 1.0;
uniform int mode : hint_range(0, 2) = 0; // 0=F1, 1=F2, 2=F2-F1
uniform float time_val : hint_range(0.0, 100000.0) = 0.0;
uniform float speed : hint_range(0.0, 5.0) = 0.0;

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

void fragment() {
	vec2 uv = UV * scale;
	vec2 cell = floor(uv);
	vec2 frac_uv = fract(uv);

	float d1 = 8.0; // F1
	float d2 = 8.0; // F2

	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 neighbor = vec2(float(dx), float(dy));
			vec2 point = hash22(cell + neighbor) * jitter;
			// Animate
			if (speed > 0.0) {
				point = 0.5 + 0.5 * sin(time_val * speed + 6.2831 * point);
			}
			float d = length(neighbor + point - frac_uv);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}

	float result;
	if (mode == 0) {
		result = d1;
	} else if (mode == 1) {
		result = d2;
	} else {
		result = d2 - d1;
	}

	COLOR = vec4(vec3(result), 1.0);
}
