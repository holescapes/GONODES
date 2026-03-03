shader_type canvas_item;
// "Plasma Globe" — Classic plasma effect, original GONODES Shadertoy conversion
// Inspired by classic demoscene plasma effects
// https://www.shadertoy.com/view/XsXXDn (related technique)

uniform vec2 gn_resolution;

void fragment() {
	// Guard against zero-resolution to prevent division by zero.
	float res_min = max(min(gn_resolution.x, gn_resolution.y), 1.0);
	vec2 uv = (FRAGCOORD.xy - gn_resolution * 0.5) / res_min;
	float t = TIME * 0.5;

	float v = 0.0;
	v += sin(uv.x * 10.0 + t);
	v += sin((uv.y * 10.0 + t) * 0.5);
	v += sin((uv.x * 10.0 + uv.y * 10.0 + t) * 0.5);

	float cx = uv.x + 0.5 * sin(t * 0.33);
	float cy = uv.y + 0.5 * cos(t * 0.5);
	v += sin(sqrt(100.0 * (cx * cx + cy * cy) + 1.0) + t);

	v *= 0.5;

	vec3 col;
	col.r = sin(v * 3.14159);
	col.g = sin(v * 3.14159 + 2.094);
	col.b = sin(v * 3.14159 + 4.188);
	col = col * 0.5 + 0.5;

	// Add subtle glow
	float glow = 1.0 - length(uv) * 0.5;
	glow = clamp(glow, 0.0, 1.0);
	col *= glow;
	// Clamp colour channels before pow to prevent NaN from
	// floating-point imprecision producing slightly negative values.
	col = max(col, vec3(0.0));
	col = pow(col, vec3(0.8));

	COLOR = vec4(col, 1.0);
}
