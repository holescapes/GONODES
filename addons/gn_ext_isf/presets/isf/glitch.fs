/*{
	"DESCRIPTION": "Digital glitch distortion — horizontal block shifts and colour channel separation",
	"CREDIT": "GONODES",
	"ISFVSN": "2.0",
	"CATEGORIES": ["Distort"],
	"INPUTS": [
		{ "NAME": "src",       "TYPE": "image" },
		{ "NAME": "amount",    "TYPE": "float", "DEFAULT": 0.1,  "MIN": 0.0, "MAX": 1.0 },
		{ "NAME": "block_size","TYPE": "float", "DEFAULT": 0.05, "MIN": 0.005,"MAX": 0.5 },
		{ "NAME": "speed",     "TYPE": "float", "DEFAULT": 3.0,  "MIN": 0.0, "MAX": 10.0 }
	]
}*/

float hash(float x) {
	return fract(sin(x * 127.1 + 311.7) * 43758.5453);
}

void main() {
	vec2 uv = isf_FragNormCoord;
	float band = floor(uv.y / block_size);
	float t = floor(TIME * speed);
	float shift = (hash(band + t) * 2.0 - 1.0) * amount;
	if (hash(band + t + 0.5) > 0.85) shift *= 3.0;

	float r = IMG_NORM_PIXEL(src, fract(uv + vec2(shift,          0.0))).r;
	float g = IMG_NORM_PIXEL(src, fract(uv + vec2(shift * 0.5,    0.0))).g;
	float b = IMG_NORM_PIXEL(src, fract(uv + vec2(shift * -0.25,  0.0))).b;
	float a = IMG_NORM_PIXEL(src, fract(uv)).a;
	gl_FragColor = vec4(r, g, b, a);
}
