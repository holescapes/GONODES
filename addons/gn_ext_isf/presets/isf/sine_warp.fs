/*{
	"DESCRIPTION": "Sinusoidal UV warp with animated speed and frequency",
	"CREDIT": "GONODES",
	"ISFVSN": "2.0",
	"CATEGORIES": ["Generator"],
	"INPUTS": [
		{ "NAME": "frequency", "TYPE": "float", "DEFAULT": 6.0, "MIN": 0.5, "MAX": 30.0 },
		{ "NAME": "amplitude", "TYPE": "float", "DEFAULT": 0.08, "MIN": 0.0, "MAX": 0.5 },
		{ "NAME": "speed",     "TYPE": "float", "DEFAULT": 1.0,  "MIN": 0.0, "MAX": 5.0 }
	]
}*/

void main() {
	vec2 uv = isf_FragNormCoord;
	uv.x += sin(uv.y * frequency + TIME * speed) * amplitude;
	uv.y += cos(uv.x * frequency + TIME * speed) * amplitude;
	vec3 col = 0.5 + 0.5 * cos(vec3(uv.x, uv.y, uv.x + uv.y) * TAU + TIME);
	gl_FragColor = vec4(col, 1.0);
}
