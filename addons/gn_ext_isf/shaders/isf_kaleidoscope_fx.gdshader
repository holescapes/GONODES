shader_type canvas_item;
// ISF-style Kaleidoscope FX — applies radial mirror symmetry to an input image.

uniform vec2 isf_rendersize;
uniform sampler2D isf_inputImage;
uniform float segments = 6.0;
uniform float angle_offset = 0.0;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float a = atan(uv.y, uv.x) + angle_offset;
	float r = length(uv);

	float seg_angle = 3.14159265 * 2.0 / max(segments, 1.0);
	a = mod(a, seg_angle);
	if (a > seg_angle * 0.5)
		a = seg_angle - a;

	vec2 kl_uv = vec2(cos(a), sin(a)) * r * 0.5 + 0.5;
	COLOR = texture(isf_inputImage, clamp(kl_uv, vec2(0.0), vec2(1.0)));
}
