shader_type canvas_item;
// ISF-style Color Bars generator — classic SMPTE-inspired color test pattern.

uniform vec2 isf_rendersize;

void fragment() {
	float x = UV.x;
	vec3 col;
	if (x < 1.0 / 7.0)       col = vec3(0.75, 0.75, 0.75);
	else if (x < 2.0 / 7.0)  col = vec3(0.75, 0.75, 0.0);
	else if (x < 3.0 / 7.0)  col = vec3(0.0, 0.75, 0.75);
	else if (x < 4.0 / 7.0)  col = vec3(0.0, 0.75, 0.0);
	else if (x < 5.0 / 7.0)  col = vec3(0.75, 0.0, 0.75);
	else if (x < 6.0 / 7.0)  col = vec3(0.75, 0.0, 0.0);
	else                      col = vec3(0.0, 0.0, 0.75);
	COLOR = vec4(col, 1.0);
}
