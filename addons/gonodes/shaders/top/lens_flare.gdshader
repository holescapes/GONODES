shader_type canvas_item;
// Procedural lens flare — ghosts, anamorphic streaks, halo ring.
// Driven by bright areas in the input image.

uniform sampler2D source_tex : hint_default_black;
uniform float threshold : hint_range(0.0, 2.0) = 0.8;
uniform float ghost_intensity : hint_range(0.0, 2.0) = 0.6;
uniform int ghost_count = 4;
uniform float ghost_spacing : hint_range(0.1, 1.0) = 0.3;
uniform float halo_radius : hint_range(0.0, 1.0) = 0.5;
uniform float halo_width : hint_range(0.01, 0.3) = 0.06;
uniform float halo_intensity : hint_range(0.0, 2.0) = 0.4;
uniform float streak_intensity : hint_range(0.0, 2.0) = 0.3;
uniform float streak_length : hint_range(0.0, 0.5) = 0.15;
uniform vec3 tint = vec3(1.0, 0.9, 0.7);

vec3 threshold_color(vec3 col, float thresh) {
	float brightness = dot(col, vec3(0.2126, 0.7152, 0.0722));
	return col * max(brightness - thresh, 0.0) / max(brightness, 0.001);
}

void fragment() {
	vec4 src = texture(source_tex, UV);
	vec3 bright = threshold_color(src.rgb, threshold);

	// Flip UV for ghost generation (lens optics invert bright sources)
	vec2 flipped = vec2(1.0) - UV;
	vec2 to_center = vec2(0.5) - flipped;

	// Ghosts — multiple displaced copies of bright areas
	vec3 ghosts = vec3(0.0);
	for (int i = 0; i < ghost_count; i++) {
		float offset = float(i + 1) * ghost_spacing;
		vec2 ghost_uv = fract(flipped + to_center * offset);
		vec3 s = threshold_color(texture(source_tex, ghost_uv).rgb, threshold);
		// Chromatic aberration per ghost
		float d = distance(ghost_uv, vec2(0.5));
		float weight = 1.0 - smoothstep(0.0, 0.75, d);
		ghosts += s * weight;
	}
	ghosts *= ghost_intensity / max(float(ghost_count), 1.0);

	// Halo ring
	float dist_to_center = distance(UV, vec2(0.5));
	float halo = 1.0 - smoothstep(halo_radius - halo_width, halo_radius, dist_to_center);
	halo *= smoothstep(halo_radius - halo_width * 2.0, halo_radius - halo_width, dist_to_center);
	vec3 halo_col = bright * halo * halo_intensity;

	// Anamorphic streak (horizontal)
	vec3 streak = vec3(0.0);
	if (streak_intensity > 0.0) {
		float streak_samples = 8.0;
		for (float i = -streak_samples; i <= streak_samples; i += 1.0) {
			vec2 offset = vec2(i * streak_length / streak_samples, 0.0);
			vec3 s = threshold_color(texture(source_tex, UV + offset).rgb, threshold);
			float w = 1.0 - abs(i) / streak_samples;
			streak += s * w * w;  // Quadratic falloff
		}
		streak *= streak_intensity / (streak_samples * 2.0 + 1.0);
	}

	// Combine
	vec3 flare = (ghosts + halo_col + streak) * tint;
	COLOR = vec4(src.rgb + flare, src.a);
}
