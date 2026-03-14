/*{
	"DESCRIPTION": "Kaleidoscope pattern generator",
	"CREDIT": "GONODES",
	"ISFVSN": "2.0",
	"CATEGORIES": ["Generator"],
	"INPUTS": [
		{ "NAME": "segments", "TYPE": "float", "DEFAULT": 8.0, "MIN": 2.0, "MAX": 32.0 },
		{ "NAME": "zoom",     "TYPE": "float", "DEFAULT": 1.5, "MIN": 0.1, "MAX": 5.0 },
		{ "NAME": "speed",    "TYPE": "float", "DEFAULT": 0.4, "MIN": 0.0, "MAX": 3.0 }
	]
}*/

void main() {
	vec2 uv = (isf_FragNormCoord - 0.5) * zoom;
	float angle = atan(uv.y, uv.x);
	float radius = length(uv);
	angle = mod(angle, TAU / segments);
	angle = abs(angle - PI / segments);
	uv = vec2(cos(angle), sin(angle)) * radius;
	vec3 col = 0.5 + 0.5 * sin(vec3(uv.x, uv.y, radius) * 5.0 + TIME * speed);
	gl_FragColor = vec4(col, 1.0);
}
