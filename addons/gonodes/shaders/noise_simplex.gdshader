shader_type canvas_item;
// Simplex/Value noise shader for NoiseTOP.
// Generates 2D noise as a grayscale or color texture.

uniform float scale : hint_range(0.1, 100.0) = 4.0;
uniform vec2 offset = vec2(0.0, 0.0);
uniform float time_offset = 0.0;
uniform int seed_val = 0;
uniform bool monochrome = true;

// --- Hash / Noise Helpers ---

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Simplex 2D noise (based on Ashima Arts / Ian McEwan)
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289_2(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x * 34.0) + 10.0) * x); }

float snoise(vec2 v) {
	const vec4 C = vec4(0.211324865405187,   // (3.0 - sqrt(3.0)) / 6.0
	                    0.366025403784439,   // 0.5 * (sqrt(3.0) - 1.0)
	                   -0.577350269189626,   // -1.0 + 2.0 * C.x
	                    0.024390243902439);  // 1.0 / 41.0
	vec2 i  = floor(v + dot(v, C.yy));
	vec2 x0 = v - i + dot(i, C.xx);

	vec2 i1;
	i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;

	i = mod289_2(i);
	vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));

	vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
	m = m * m;
	m = m * m;

	vec3 x = 2.0 * fract(p * C.www) - 1.0;
	vec3 h = abs(x) - 0.5;
	vec3 ox = floor(x + 0.5);
	vec3 a0 = x - ox;

	m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);

	vec3 g;
	g.x = a0.x * x0.x + h.x * x0.y;
	g.yz = a0.yz * x12.xz + h.yz * x12.yw;

	return 130.0 * dot(m, g);
}

void fragment() {
	vec2 uv = UV * scale + offset + vec2(float(seed_val) * 0.7123, float(seed_val) * 0.3917);
	float t = time_offset;

	// Use time as a Z-axis offset to animate the noise
	float n = snoise(uv + vec2(t * 0.5, t * 0.3));
	// Remap from [-1, 1] to [0, 1]
	n = n * 0.5 + 0.5;

	if (monochrome) {
		COLOR = vec4(vec3(n), 1.0);
	} else {
		// Generate RGB channels with offset seeds
		float r = snoise(uv + vec2(t * 0.5, t * 0.3)) * 0.5 + 0.5;
		float g = snoise(uv + vec2(t * 0.3 + 100.0, t * 0.5 + 100.0)) * 0.5 + 0.5;
		float b = snoise(uv + vec2(t * 0.7 + 200.0, t * 0.2 + 200.0)) * 0.5 + 0.5;
		COLOR = vec4(r, g, b, 1.0);
	}
}
