shader_type canvas_item;
// ColorMapTOP — remap grayscale input through a color gradient texture (LUT).

uniform sampler2D source_tex : hint_default_white;
uniform sampler2D gradient_tex : hint_default_white;
uniform int luma_mode : hint_range(0, 3) = 0; // 0=Luminance, 1=R, 2=G, 3=B
uniform float intensity = 1.0;

void fragment() {
	vec4 col = texture(source_tex, UV);

	float val;
	if (luma_mode == 0) {
		val = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
	} else if (luma_mode == 1) {
		val = col.r;
	} else if (luma_mode == 2) {
		val = col.g;
	} else {
		val = col.b;
	}

	vec4 mapped = texture(gradient_tex, vec2(clamp(val, 0.0, 1.0), 0.5));
	COLOR = vec4(mix(col.rgb, mapped.rgb, intensity), col.a);
}
