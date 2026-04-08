shader_type canvas_item;
// Digital glitch — multi-layer corruption: block displacement, channel shift,
// scan-line jitter, horizontal tears, colour crush, static noise, and
// V002-style stale-frame injection.

uniform sampler2D source_tex : hint_default_white;
uniform float block_size : hint_range(4.0, 128.0) = 32.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.3;
uniform float channel_shift : hint_range(0.0, 0.05) = 0.01;
uniform float time_val : hint_range(0.0, 100000.0) = 0.0;
uniform float speed : hint_range(0.1, 30.0) = 8.0;

// --- additional layers (0 = disabled) ---
uniform float scan_jitter : hint_range(0.0, 0.1) = 0.0;
uniform float tear_strength : hint_range(0.0, 1.0) = 0.0;
uniform float color_crush : hint_range(0.0, 1.0) = 0.0;
uniform float noise_amount : hint_range(0.0, 1.0) = 0.0;
uniform float stale_mix : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D stale_tex : hint_default_white;

// ---- cheap hash helpers ------------------------------------------------
float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec2 tex_size = vec2(textureSize(source_tex, 0));
	float time_q = floor(time_val * speed);
	vec2 uv = UV;

	// --- 1. Scan-line jitter (VHS tracking) ---
	if (scan_jitter > 0.0) {
		float line = floor(UV.y * tex_size.y);
		float line_rand = hash2(vec2(line, time_q));
		if (line_rand < intensity) {
			uv.x += (hash2(vec2(line + 0.5, time_q)) * 2.0 - 1.0) * scan_jitter;
		}
	}

	// --- 2. Horizontal tear bands ---
	if (tear_strength > 0.0) {
		// Up to 3 tear bands per quantum
		for (int i = 0; i < 3; i++) {
			float tear_seed = float(i) * 17.0 + 7.0;
			float tear_y = hash2(vec2(time_q, tear_seed));
			float tear_h = hash2(vec2(time_q, tear_seed + 53.0)) * 0.08 + 0.01;
			if (uv.y > tear_y && uv.y < tear_y + tear_h) {
				float shift_dir = hash2(vec2(time_q, tear_seed + 91.0)) * 2.0 - 1.0;
				uv.x += shift_dir * tear_strength * 0.25;
			}
		}
	}

	// --- 3. Block displacement (original behaviour) ---
	vec2 block = floor(uv * tex_size / block_size);
	float rand_block = hash2(block + vec2(time_q));

	if (rand_block < intensity) {
		float offset_x = (hash2(block + vec2(time_q + 1.0)) * 2.0 - 1.0) * intensity * 0.1;
		uv.x += offset_x;
	}

	// --- 4. Channel shift ---
	float shift = channel_shift * (hash2(vec2(floor(uv.y * tex_size.y / block_size), time_q)) * 2.0 - 1.0);

	float r = texture(source_tex, clamp(uv + vec2(shift, 0.0), vec2(0.0), vec2(1.0))).r;
	float g = texture(source_tex, clamp(uv, vec2(0.0), vec2(1.0))).g;
	float b = texture(source_tex, clamp(uv - vec2(shift, 0.0), vec2(0.0), vec2(1.0))).b;
	float a = texture(source_tex, uv).a;
	vec3 result = vec3(r, g, b);

	// --- 5. Colour crush (bit-depth reduction in glitch blocks) ---
	if (color_crush > 0.0 && rand_block < intensity) {
		float bits = mix(8.0, 1.0, color_crush);
		float steps = pow(2.0, bits);
		result = floor(result * steps + 0.5) / steps;
	}

	// --- 6. V002-style stale-frame injection ---
	if (stale_mix > 0.0) {
		// Use a different hash so stale blocks don't perfectly overlap displacement blocks
		float stale_rand = hash3(vec3(block, time_q + 77.0));
		if (stale_rand < intensity * stale_mix) {
			vec3 stale_col = texture(stale_tex, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
			// Hard swap (like real FBO corruption) rather than blend
			result = stale_col;
		}
	}

	// --- 7. Static noise (analog snow / digital static) ---
	if (noise_amount > 0.0) {
		float px_rand = hash3(vec3(UV * tex_size, time_val));
		float noise_mask = step(1.0 - intensity * noise_amount, hash2(block + vec2(time_q + 3.0)));
		result = mix(result, vec3(px_rand), noise_mask * noise_amount);
	}

	COLOR = vec4(result, a);
}
