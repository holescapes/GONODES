shader_type canvas_item;
// ChannelMixTOP — remap/swap RGBA channels with per-channel source selection and gain.

uniform sampler2D source_tex : hint_default_white;
// 0=R, 1=G, 2=B, 3=A, 4=Luminance, 5=Zero, 6=One
uniform int r_source : hint_range(0, 6) = 0;
uniform int g_source : hint_range(0, 6) = 1;
uniform int b_source : hint_range(0, 6) = 2;
uniform int a_source : hint_range(0, 6) = 3;
uniform float r_gain = 1.0;
uniform float g_gain = 1.0;
uniform float b_gain = 1.0;
uniform float a_gain = 1.0;

float get_channel(vec4 c, int src) {
	float lum = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	if (src == 0) return c.r;
	else if (src == 1) return c.g;
	else if (src == 2) return c.b;
	else if (src == 3) return c.a;
	else if (src == 4) return lum;
	else if (src == 5) return 0.0;
	else return 1.0;
}

void fragment() {
	vec4 c = texture(source_tex, UV);
	COLOR = vec4(
		get_channel(c, r_source) * r_gain,
		get_channel(c, g_source) * g_gain,
		get_channel(c, b_source) * b_gain,
		get_channel(c, a_source) * a_gain
	);
}
