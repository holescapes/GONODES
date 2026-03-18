shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Fluid surface material: refraction, fresnel, depth fade, animated caustics.
// Designed for FluidVOL → MarchingCubes → GeometryCOMP pipeline.

uniform vec4 deep_color : source_color = vec4(0.02, 0.08, 0.25, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.1, 0.5, 0.7, 1.0);
uniform float depth_fade : hint_range(0.1, 10.0) = 2.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.85;

// Fresnel
uniform float fresnel_power : hint_range(0.5, 10.0) = 3.0;
uniform float fresnel_bias : hint_range(0.0, 1.0) = 0.1;

// Refraction
uniform float refraction_strength : hint_range(0.0, 1.0) = 0.15;

// Specular / Roughness
uniform float metallic_val : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.05;
uniform float specular_val : hint_range(0.0, 1.0) = 0.8;

// Caustics
uniform bool caustics_enabled = true;
uniform float caustics_scale : hint_range(0.5, 20.0) = 5.0;
uniform float caustics_speed : hint_range(0.0, 5.0) = 0.8;
uniform float caustics_intensity : hint_range(0.0, 2.0) = 0.4;

// Normal perturbation (wave ripples)
uniform float wave_scale : hint_range(0.5, 50.0) = 8.0;
uniform float wave_speed : hint_range(0.0, 5.0) = 0.5;
uniform float wave_strength : hint_range(0.0, 0.5) = 0.08;

// Optional normal map texture
uniform sampler2D normal_map : hint_normal;
uniform bool use_normal_map = false;
uniform float normal_map_strength : hint_range(0.0, 2.0) = 1.0;

// --- Hash helpers for procedural caustics ---

vec2 _hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// Voronoi-based caustic pattern — two layers blended for shimmer
float caustic_pattern(vec2 uv, float time_val) {
	float c1 = 0.0;
	float c2 = 0.0;
	// Layer 1
	{
		vec2 p = uv * caustics_scale;
		p += vec2(time_val * caustics_speed * 0.3, time_val * caustics_speed * 0.2);
		vec2 i = floor(p);
		vec2 f = fract(p);
		float min_d = 1.0;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 nb = vec2(float(x), float(y));
				vec2 pt = _hash22(i + nb);
				pt = 0.5 + 0.5 * sin(time_val * 2.0 + 6.283 * pt);
				float d = length(nb + pt - f);
				min_d = min(min_d, d);
			}
		}
		c1 = min_d;
	}
	// Layer 2 (offset)
	{
		vec2 p = uv * caustics_scale * 1.3 + vec2(50.0);
		p += vec2(-time_val * caustics_speed * 0.2, time_val * caustics_speed * 0.35);
		vec2 i = floor(p);
		vec2 f = fract(p);
		float min_d = 1.0;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 nb = vec2(float(x), float(y));
				vec2 pt = _hash22(i + nb);
				pt = 0.5 + 0.5 * sin(time_val * 1.7 + 6.283 * pt);
				float d = length(nb + pt - f);
				min_d = min(min_d, d);
			}
		}
		c2 = min_d;
	}
	// Combine: minimum of two layers creates bright caustic lines
	float c = min(c1, c2);
	c = pow(1.0 - c, 3.0);  // sharpen into bright lines
	return c;
}

// Simple procedural wave normal perturbation
vec3 wave_normal(vec2 uv, float time_val) {
	float s = wave_scale;
	float t = time_val * wave_speed;
	float dx = cos(uv.x * s + t) * sin(uv.y * s * 0.7 + t * 1.3) * wave_strength;
	float dy = sin(uv.x * s * 0.8 - t * 0.9) * cos(uv.y * s + t * 0.7) * wave_strength;
	return normalize(vec3(dx, dy, 1.0));
}

void fragment() {
	// Fresnel term
	float ndotv = dot(NORMAL, VIEW);
	float fresnel = fresnel_bias + (1.0 - fresnel_bias) * pow(1.0 - clamp(ndotv, 0.0, 1.0), fresnel_power);

	// Color: blend between deep and shallow based on view angle
	vec3 base_color = mix(deep_color.rgb, shallow_color.rgb, fresnel);

	// Caustics overlay
	if (caustics_enabled) {
		vec2 caustic_uv = (NODE_POSITION_WORLD.xz + NODE_POSITION_WORLD.xy) * 0.5;
		float c = caustic_pattern(caustic_uv, TIME);
		base_color += vec3(c * caustics_intensity);
	}

	// Wave normal perturbation
	vec3 perturbed_n = wave_normal(UV, TIME);
	if (use_normal_map) {
		vec3 nm = texture(normal_map, UV).rgb * 2.0 - 1.0;
		perturbed_n = normalize(perturbed_n + nm * normal_map_strength);
	}

	ALBEDO = base_color;
	METALLIC = metallic_val;
	ROUGHNESS = roughness_val;
	SPECULAR = specular_val;
	NORMAL_MAP = perturbed_n;
	NORMAL_MAP_DEPTH = 1.0;

	// Refraction (screen-space)
	EMISSION = vec3(0.0);
	BACKLIGHT = vec3(refraction_strength);

	// Alpha with fresnel
	ALPHA = clamp(opacity + fresnel * 0.3, 0.0, 1.0);
}
