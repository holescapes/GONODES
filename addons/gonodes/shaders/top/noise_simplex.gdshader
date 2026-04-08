shader_type canvas_item;
// Noise shader for NoiseTOP.
// Generates 2D noise: Simplex (0), Perlin (1), Voronoi (2), White (3), Value (4), Ridged (5).

uniform int noise_type = 0; // 0=Simplex, 1=Perlin, 2=Voronoi, 3=White, 4=Value, 5=Ridged
uniform float scale : hint_range(0.1, 100.0) = 4.0;
uniform vec2 offset = vec2(0.0, 0.0);
uniform float time_offset = 0.0;
uniform int seed_val = 0;
uniform bool monochrome = true;
uniform int octaves = 1;         // FBM octave count (1 = single pass)
uniform float lacunarity = 2.0;  // frequency multiplier per octave
uniform float gain = 0.5;        // amplitude multiplier per octave
uniform bool periodic = false;   // seamless tiling mode
uniform float tile_size = 4.0;   // tile period (in noise-space units)

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

// Perlin-style gradient noise (classic grid-based)
float pnoise(vec2 v) {
	vec2 i = floor(v);
	vec2 f = fract(v);
	vec2 u = f * f * (3.0 - 2.0 * f); // smoothstep

	float a = hash21(i + vec2(0.0, 0.0));
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}

// Voronoi (Worley) noise — returns distance to nearest cell center
float voronoi(vec2 v) {
	vec2 i = floor(v);
	vec2 f = fract(v);
	float min_dist = 1.0;

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = hash22(i + neighbor);
			vec2 diff = neighbor + point - f;
			float d = length(diff);
			min_dist = min(min_dist, d);
		}
	}
	return min_dist * 2.0 - 1.0; // remap to [-1, 1]
}

// White noise (fully random per pixel)
float wnoise(vec2 v) {
	return hash21(v) * 2.0 - 1.0;
}

// Value noise — blocky grid-interpolated random values
float vnoise(vec2 v) {
	vec2 i = floor(v);
	vec2 f = fract(v);
	// Quintic interpolation (smoother than cubic smoothstep)
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash21(i + vec2(0.0, 0.0));
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}

// Single-sample noise dispatch (no FBM) — returns value in [-1, 1]
float get_noise_raw(vec2 v) {
	if (noise_type == 1) {
		return pnoise(v);
	} else if (noise_type == 2) {
		return voronoi(v);
	} else if (noise_type == 3) {
		return wnoise(v);
	} else if (noise_type == 4) {
		return vnoise(v);
	} else if (noise_type == 5) {
		// Ridged uses Simplex as base, abs() applied in FBM loop
		return snoise(v);
	}
	return snoise(v); // 0 = Simplex (default)
}

// --- Periodic (tileable) Perlin noise ---
// Uses mod-wrapped integer lattice so the pattern repeats every 'period' cells.

float periodic_hash(vec2 p, float period) {
	p = mod(p, period);
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float periodic_pnoise(vec2 v, float period) {
	vec2 i = floor(v);
	vec2 f = fract(v);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = periodic_hash(i + vec2(0.0, 0.0), period);
	float b = periodic_hash(i + vec2(1.0, 0.0), period);
	float c = periodic_hash(i + vec2(0.0, 1.0), period);
	float d = periodic_hash(i + vec2(1.0, 1.0), period);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}

// --- FBM (fractal Brownian motion) wrapper ---

float fbm_noise(vec2 v) {
	float value = 0.0;
	float amplitude = 1.0;
	float frequency = 1.0;
	float total_amp = 0.0;
	for (int i = 0; i < octaves; i++) {
		vec2 p = v * frequency;
		float n;
		if (periodic) {
			n = periodic_pnoise(p, tile_size * frequency);
		} else {
			n = get_noise_raw(p);
		}
		// Ridged: abs() creates sharp ridges, invert so ridges are peaks
		if (noise_type == 5) {
			n = 1.0 - abs(n);
			n = n * n; // sharpen the ridges
		}
		value += amplitude * n;
		total_amp += amplitude;
		frequency *= lacunarity;
		amplitude *= gain;
	}
	return (total_amp > 0.0) ? value / total_amp : 0.0;
}

// Dispatch noise by type — returns value in [-1, 1]
float get_noise(vec2 v) {
	if (octaves > 1 || periodic || noise_type == 5) {
		return fbm_noise(v);
	}
	return get_noise_raw(v);
}

void fragment() {
	vec2 uv = UV * scale + offset + vec2(float(seed_val) * 0.7123, float(seed_val) * 0.3917);
	float t = time_offset;

	// Use time as a Z-axis offset to animate the noise
	float n = get_noise(uv + vec2(t * 0.5, t * 0.3));
	// Remap from [-1, 1] to [0, 1]
	n = n * 0.5 + 0.5;

	if (monochrome) {
		COLOR = vec4(vec3(n), 1.0);
	} else {
		// Generate RGB channels with offset seeds
		float r = get_noise(uv + vec2(t * 0.5, t * 0.3)) * 0.5 + 0.5;
		float g = get_noise(uv + vec2(t * 0.3 + 100.0, t * 0.5 + 100.0)) * 0.5 + 0.5;
		float b = get_noise(uv + vec2(t * 0.7 + 200.0, t * 0.2 + 200.0)) * 0.5 + 0.5;
		COLOR = vec4(r, g, b, 1.0);
	}
}
