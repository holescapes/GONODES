/*{
	"DESCRIPTION": "Kaleidoscope effect on an input image",
	"CREDIT": "GONODES",
	"ISFVSN": "2.0",
	"CATEGORIES": ["Stylize"],
	"INPUTS": [
		{ "NAME": "src",      "TYPE": "image" },
		{ "NAME": "segments", "TYPE": "float", "DEFAULT": 6.0,  "MIN": 2.0, "MAX": 24.0 },
		{ "NAME": "zoom",     "TYPE": "float", "DEFAULT": 1.0,  "MIN": 0.2, "MAX": 4.0 },
		{ "NAME": "rotation", "TYPE": "float", "DEFAULT": 0.0,  "MIN": 0.0, "MAX": 360.0 }
	]
}*/

void main() {
	vec2 uv = (isf_FragNormCoord - 0.5) * zoom;
	float rot = radians(rotation);
	float cs = cos(rot), sn = sin(rot);
	uv = vec2(uv.x * cs - uv.y * sn, uv.x * sn + uv.y * cs);
	float angle = atan(uv.y, uv.x);
	float radius = length(uv);
	angle = mod(angle, TAU / segments);
	angle = abs(angle - PI / segments);
	uv = vec2(cos(angle), sin(angle)) * radius + 0.5;
	gl_FragColor = IMG_NORM_PIXEL(src, fract(uv));
}
