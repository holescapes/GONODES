shader_type canvas_item;
// Curl noise — 2D divergence-free vector field from noise derivatives.
// Output: R = curl.x, G = curl.y (remapped to 0-1), B = 0, A = 1.
// Use for fluid advection, particle motion, flow-field effects.

uniform float scale : hint_range(0.1, 100.0) = 4.0;
uniform vec2 offset = vec2(0.0, 0.0);
uniform float time_offset = 0.0;
uniform int seed_val = 0;
uniform int octaves = 1;
uniform float lacunarity = 2.0;
uniform float gain = 0.5;

// --- Hash / Simplex helpers ---

vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289_2(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x * 34.0) + 10.0) * x); }

float snoise(vec2 v) {
	const vec4 C = vec4(0.211324865405187, 0.366025403784439,
	                   -0.577350269189626, 0.024390243902439);
	vec2 i  = floor(v + dot(v, C.yy));
	vec2 x0 = v - i + dot(i, C.xx);
	vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
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

// FBM wrapper for curl base noise
float fbm(vec2 v) {
	float value = 0.0;
	float amplitude = 1.0;
	float frequency = 1.0;
	float total_amp = 0.0;
	for (int i = 0; i < octaves; i++) {
		value += amplitude * snoise(v * frequency);
		total_amp += amplitude;
		frequency *= lacunarity;
		amplitude *= gain;
	}
	return (total_amp > 0.0) ? value / total_amp : 0.0;
}

// Curl noise via finite differences of a potential field.
// Two noise fields (offset by large constant) form the potential;
// curl = (dPsi2/dx, -dPsi1/dy) gives a divergence-free 2D vector field.
vec2 curl_noise(vec2 v) {
	float eps = 0.001;
	// Potential field 1 (for y-component of curl)
	float n1_dx = fbm(v + vec2(eps, 0.0)) - fbm(v - vec2(eps, 0.0));
	// Potential field 2 (for x-component of curl) — offset seed
	float n2_dy = fbm(v + vec2(500.0, 0.0) + vec2(0.0, eps)) - fbm(v + vec2(500.0, 0.0) - vec2(0.0, eps));
	return vec2(n2_dy, -n1_dx) / (2.0 * eps);
}

void fragment() {
	vec2 uv = UV * scale + offset + vec2(float(seed_val) * 0.7123, float(seed_val) * 0.3917);
	float t = time_offset;
	uv += vec2(t * 0.5, t * 0.3);

	vec2 c = curl_noise(uv);
	// Normalize to visible range — curl values are typically small
	// Remap from roughly [-1,1] to [0,1]
	c = c * 0.5 + 0.5;
	COLOR = vec4(c.x, c.y, 0.0, 1.0);
}
