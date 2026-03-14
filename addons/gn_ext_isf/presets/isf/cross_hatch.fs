/*{
	"DESCRIPTION": "Animated cross-hatch sketch effect",
	"CREDIT": "GONODES",
	"ISFVSN": "2.0",
	"CATEGORIES": ["Stylize"],
	"INPUTS": [
		{ "NAME": "src",        "TYPE": "image" },
		{ "NAME": "line_freq",  "TYPE": "float",  "DEFAULT": 40.0, "MIN": 5.0, "MAX": 120.0 },
		{ "NAME": "line_width", "TYPE": "float",  "DEFAULT": 0.3,  "MIN": 0.05,"MAX": 0.9 },
		{ "NAME": "paper",      "TYPE": "color",  "DEFAULT": [0.95, 0.93, 0.85, 1.0] },
		{ "NAME": "ink",        "TYPE": "color",  "DEFAULT": [0.1, 0.05, 0.0, 1.0] }
	]
}*/

float luma(vec4 c) { return dot(c.rgb, vec3(0.299, 0.587, 0.114)); }

float hatch_line(vec2 uv, float angle, float freq, float width) {
	vec2 rot = vec2(cos(angle) * uv.x - sin(angle) * uv.y,
	                sin(angle) * uv.x + cos(angle) * uv.y);
	float line = mod(rot.x * freq, 1.0);
	return step(line, width);
}

void main() {
	vec2 uv = isf_FragNormCoord;
	float dark = 1.0 - luma(IMG_NORM_PIXEL(src, uv));

	float h = 0.0;
	if (dark > 0.2) h += hatch_line(uv, 0.785,   line_freq, line_width * dark);
	if (dark > 0.4) h += hatch_line(uv, 2.356,   line_freq, line_width * dark);
	if (dark > 0.6) h += hatch_line(uv, 1.571,   line_freq, line_width * dark);
	if (dark > 0.8) h += hatch_line(uv, 0.0,     line_freq, line_width * dark);
	h = clamp(h, 0.0, 1.0);

	gl_FragColor = mix(paper, ink, h);
}
