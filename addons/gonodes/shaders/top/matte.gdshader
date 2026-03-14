shader_type canvas_item;
// Matte shader — applies alpha from a second texture to the base.

uniform sampler2D source_tex : hint_default_white;
uniform sampler2D matte_tex : hint_default_white;
uniform int matte_channel : hint_range(0, 4) = 0;  // 0=Luma,1=R,2=G,3=B,4=A
uniform bool invert_matte = false;
uniform bool premultiply = false;

float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec4 base = texture(source_tex, UV);
	vec4 matte = texture(matte_tex, UV);

	float m = 0.0;
	if (matte_channel == 0) {
		m = luminance(matte.rgb);
	} else if (matte_channel == 1) {
		m = matte.r;
	} else if (matte_channel == 2) {
		m = matte.g;
	} else if (matte_channel == 3) {
		m = matte.b;
	} else {
		m = matte.a;
	}

	if (invert_matte) {
		m = 1.0 - m;
	}

	base.a = m;

	if (premultiply) {
		base.rgb *= m;
	}

	COLOR = base;
}
