/*{
	"DESCRIPTION": "Mirror the input image along a configurable axis",
	"CREDIT": "GONODES",
	"ISFVSN": "2.0",
	"CATEGORIES": ["Distort"],
	"INPUTS": [
		{ "NAME": "src",  "TYPE": "image" },
		{ "NAME": "mode", "TYPE": "long",
		  "VALUES": [0, 1, 2, 3],
		  "LABELS": ["Horizontal", "Vertical", "Both", "Diagonal"],
		  "DEFAULT": 0 }
	]
}*/

void main() {
	vec2 uv = isf_FragNormCoord;
	if (mode == 0) uv.x = 1.0 - abs(uv.x * 2.0 - 1.0);
	else if (mode == 1) uv.y = 1.0 - abs(uv.y * 2.0 - 1.0);
	else if (mode == 2) {
		uv.x = 1.0 - abs(uv.x * 2.0 - 1.0);
		uv.y = 1.0 - abs(uv.y * 2.0 - 1.0);
	} else {
		float tmp = uv.x;
		uv.x = uv.y;
		uv.y = tmp;
	}
	gl_FragColor = IMG_NORM_PIXEL(src, uv);
}
