shader_type canvas_item;
// ISF-style Lissajous generator — animated parametric curves.

uniform vec2 isf_rendersize;
uniform float freq_x = 3.0;
uniform float freq_y = 2.0;
uniform float phase = 0.0;
uniform float line_width = 0.008;
uniform float trail_length = 200.0;
uniform vec4 line_color = vec4(0.2, 0.8, 1.0, 1.0);
uniform vec4 bg_color = vec4(0.02, 0.02, 0.05, 1.0);

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float min_dist = 1.0;
	float glow = 0.0;

	for (float i = 0.0; i < 200.0; i += 1.0) {
		if (i >= trail_length) break;
		float t = TIME + i * 0.005;
		vec2 p = vec2(
			sin(t * freq_x + phase),
			sin(t * freq_y)
		) * 0.75;
		float d = length(uv - p);
		min_dist = min(min_dist, d);
		glow += exp(-d * 200.0) * (1.0 - i / trail_length);
	}

	float line = smoothstep(line_width, 0.0, min_dist);
	vec4 col = mix(bg_color, line_color, clamp(line + glow * 0.3, 0.0, 1.0));
	col.a = 1.0;
	COLOR = col;
}
