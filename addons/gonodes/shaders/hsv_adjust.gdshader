shader_type canvas_item;
// HSV adjustment shader for HSVAdjustTOP.
// Adjusts hue, saturation, and value of input texture.

uniform sampler2D source_tex : hint_default_white;
uniform float hue_offset = 0.0;      // -1.0 to 1.0 (wraps)
uniform float saturation_mult = 1.0; // 0 = grayscale, 1 = original, >1 = oversaturated
uniform float value_mult = 1.0;      // brightness multiplier

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 col = texture(source_tex, UV);
	vec3 hsv = rgb2hsv(col.rgb);

	hsv.x = fract(hsv.x + hue_offset);
	hsv.y *= saturation_mult;
	hsv.z *= value_mult;

	COLOR = vec4(hsv2rgb(hsv), col.a);
}
