/*{
	"DESCRIPTION": "Lissajous figure generator — animated XY-ratio pattern",
	"CREDIT": "GONODES",
	"ISFVSN": "2.0",
	"CATEGORIES": ["Generator"],
	"INPUTS": [
		{ "NAME": "freq_x",    "TYPE": "float", "DEFAULT": 3.0,  "MIN": 1.0, "MAX": 12.0 },
		{ "NAME": "freq_y",    "TYPE": "float", "DEFAULT": 2.0,  "MIN": 1.0, "MAX": 12.0 },
		{ "NAME": "phase",     "TYPE": "float", "DEFAULT": 0.0,  "MIN": 0.0, "MAX": 6.283 },
		{ "NAME": "line_width","TYPE": "float", "DEFAULT": 0.015,"MIN": 0.001,"MAX": 0.1 },
		{ "NAME": "speed",     "TYPE": "float", "DEFAULT": 0.5,  "MIN": 0.0, "MAX": 3.0 },
		{ "NAME": "color",     "TYPE": "color", "DEFAULT": [0.2, 0.9, 0.6, 1.0] }
	]
}*/

void main() {
	vec2 uv = isf_FragNormCoord * 2.0 - 1.0;
	float t = TIME * speed;
	vec2 liss = vec2(sin(freq_x * t + phase), sin(freq_y * t));
	float dist = length(uv - liss);
	float brightness = smoothstep(line_width, 0.0, dist);
	gl_FragColor = vec4(color.rgb * brightness, brightness);
}
