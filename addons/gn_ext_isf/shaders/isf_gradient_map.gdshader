shader_type canvas_item;
// ISF-style Gradient Map generator — animated horizontal gradient with 3 color stops.

uniform vec2 isf_rendersize;
uniform vec4 left_color = vec4(0.0, 0.0, 0.2, 1.0);
uniform vec4 mid_color = vec4(0.2, 0.5, 0.9, 1.0);
uniform vec4 right_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform float offset = 0.0;
uniform float scale = 1.0;

void fragment() {
	float t = fract(UV.x * scale + offset + TIME * 0.1);
	vec4 col;
	if (t < 0.5)
		col = mix(left_color, mid_color, t * 2.0);
	else
		col = mix(mid_color, right_color, (t - 0.5) * 2.0);
	col.a = 1.0;
	COLOR = col;
}
