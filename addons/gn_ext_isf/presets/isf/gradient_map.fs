/*{
	"DESCRIPTION": "Gradient map between two colours over normalised UV",
	"CREDIT": "GONODES",
	"ISFVSN": "2.0",
	"CATEGORIES": ["Generator"],
	"INPUTS": [
		{ "NAME": "color_a",   "TYPE": "color",  "DEFAULT": [0.0, 0.05, 0.3, 1.0] },
		{ "NAME": "color_b",   "TYPE": "color",  "DEFAULT": [1.0, 0.6, 0.0, 1.0] },
		{ "NAME": "angle",     "TYPE": "float",  "DEFAULT": 0.0,  "MIN": 0.0, "MAX": 360.0 },
		{ "NAME": "animate",   "TYPE": "bool",   "DEFAULT": false },
		{ "NAME": "anim_speed","TYPE": "float",  "DEFAULT": 0.5,  "MIN": 0.0, "MAX": 3.0 }
	]
}*/

void main() {
	vec2 uv = isf_FragNormCoord;
	float rad = radians(angle);
	vec2 dir = vec2(cos(rad), sin(rad));
	float t = dot(uv - 0.5, dir) + 0.5;
	if (animate) t = mod(t + TIME * anim_speed, 1.0);
	t = clamp(t, 0.0, 1.0);
	gl_FragColor = mix(color_a, color_b, t);
}
