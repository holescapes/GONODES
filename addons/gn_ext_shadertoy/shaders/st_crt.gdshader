shader_type canvas_item;
// CRT Effect — scanlines, barrel distortion, vignette
// Inspired by various Shadertoy CRT shaders

uniform sampler2D gn_tex0 : hint_default_white;
uniform vec2 gn_resolution;
uniform float curvature = 4.0;      // Barrel distortion strength (0 = none)
uniform float scanline_weight = 0.15; // Scanline darkness
uniform float vignette_strength = 0.4;

vec2 crt_curve(vec2 uv) {
	uv = uv * 2.0 - 1.0;
	vec2 offset = abs(uv.yx) / vec2(curvature);
	uv = uv + uv * offset * offset;
	return uv * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = crt_curve(UV);

	// Out-of-bounds → black
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}

	vec4 col = texture(gn_tex0, uv);

	// Scanlines
	float scanline = clamp(0.95 + scanline_weight * cos(3.14159 * uv.y * gn_resolution.y), 0.0, 1.0);
	col.rgb *= scanline;

	// RGB sub-pixel grille
	float grille = 0.85 + 0.15 * clamp(1.5 * cos(3.14159 * uv.x * gn_resolution.x), 0.0, 1.0);
	col.rgb *= grille;

	// Vignette
	float vig = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
	vig = clamp(pow(16.0 * vig, vignette_strength), 0.0, 1.0);
	col.rgb *= vig;

	// Slight brightness boost to compensate for darkening
	col.rgb *= 1.2;

	COLOR = col;
}
