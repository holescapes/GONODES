shader_type canvas_item;
// CMYK Halftone — converts image to CMYK halftone dot pattern
// Translated from Shadertoy — "CMYK Halftone" by tsone
// https://www.shadertoy.com/view/Mdf3Dn

uniform sampler2D gn_tex0 : hint_default_white;
uniform vec2 gn_resolution;
uniform float dot_size = 1.48;
uniform float dot_scale = 10.0;  // Controls dot grid size

#define SST 0.888
#define SSQ 0.288

vec4 rgb2cmyki(in vec3 c) {
	float k = max(max(c.r, c.g), c.b);
	// Guard against division by zero for pure-black pixels.
	return min(vec4(c.rgb / max(k, 0.0001), k), 1.0);
}

vec3 cmyki2rgb(in vec4 c) {
	return c.rgb * c.a;
}

vec2 grid(in vec2 px, float s) {
	return px - mod(px, s);
}

vec4 ss(in vec4 v) {
	return smoothstep(SST - SSQ, SST + SSQ, v);
}

vec4 halftone(in vec2 fc, in mat2 m, float s) {
	vec2 smp = (grid(m * fc, s) + 0.5 * s) * m;
	float d = min(length(fc - smp) / (dot_size * 0.5 * s), 1.0);
	vec2 uv = (smp + 0.5 * gn_resolution) / gn_resolution;
	vec3 texc = texture(gn_tex0, uv).rgb;
	texc = pow(max(texc, vec3(0.0)), vec3(2.2));
	vec4 c = rgb2cmyki(texc);
	return c + d;
}

mat2 rotm(in float r) {
	float cr = cos(r);
	float sr = sin(r);
	return mat2(vec2(cr, -sr), vec2(sr, cr));
}

void fragment() {
	float s = dot_scale;
	float r = 0.0;
	vec2 fc = FRAGCOORD.xy - 0.5 * gn_resolution;

	mat2 mc = rotm(r + radians(15.0));
	mat2 mm = rotm(r + radians(75.0));
	mat2 my = rotm(r);
	mat2 mk = rotm(r + radians(45.0));

	float k = halftone(fc, mk, s).a;
	vec3 c = cmyki2rgb(ss(vec4(
		halftone(fc, mc, s).r,
		halftone(fc, mm, s).g,
		halftone(fc, my, s).b,
		halftone(fc, mk, s).a
	)));

	c = pow(c, vec3(1.0 / 2.2));
	COLOR = vec4(c, 1.0);
}
