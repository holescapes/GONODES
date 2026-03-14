/*{
	"DESCRIPTION": "Animated edge detection glow using a Sobel kernel",
	"CREDIT": "GONODES",
	"ISFVSN": "2.0",
	"CATEGORIES": ["Stylize"],
	"INPUTS": [
		{ "NAME": "src",        "TYPE": "image" },
		{ "NAME": "edge_color", "TYPE": "color",  "DEFAULT": [0.0, 0.8, 1.0, 1.0] },
		{ "NAME": "threshold",  "TYPE": "float",  "DEFAULT": 0.2, "MIN": 0.0, "MAX": 1.0 },
		{ "NAME": "glow_width", "TYPE": "float",  "DEFAULT": 3.0, "MIN": 1.0, "MAX": 20.0 },
		{ "NAME": "show_src",   "TYPE": "bool",   "DEFAULT": true }
	]
}*/

float luma(vec4 c) { return dot(c.rgb, vec3(0.299, 0.587, 0.114)); }

void main() {
	vec2 uv = isf_FragNormCoord;
	vec2 px = 1.0 / RENDERSIZE;
	vec2 off = px * glow_width;

	float tl = luma(IMG_NORM_PIXEL(src, uv + vec2(-off.x,  off.y)));
	float t  = luma(IMG_NORM_PIXEL(src, uv + vec2(0.0,     off.y)));
	float tr = luma(IMG_NORM_PIXEL(src, uv + vec2( off.x,  off.y)));
	float ml = luma(IMG_NORM_PIXEL(src, uv + vec2(-off.x, 0.0)));
	float mr = luma(IMG_NORM_PIXEL(src, uv + vec2( off.x, 0.0)));
	float bl = luma(IMG_NORM_PIXEL(src, uv + vec2(-off.x, -off.y)));
	float b  = luma(IMG_NORM_PIXEL(src, uv + vec2(0.0,    -off.y)));
	float br = luma(IMG_NORM_PIXEL(src, uv + vec2( off.x, -off.y)));

	float gx = -tl - 2.0*ml - bl + tr + 2.0*mr + br;
	float gy = -tl - 2.0*t  - tr + bl + 2.0*b  + br;
	float edge = smoothstep(threshold, threshold + 0.1, length(vec2(gx, gy)));

	vec4 base = show_src ? IMG_NORM_PIXEL(src, uv) : vec4(0.0);
	gl_FragColor = base + edge_color * edge;
}
