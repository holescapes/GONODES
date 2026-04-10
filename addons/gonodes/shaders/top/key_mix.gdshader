shader_type canvas_item;
// KeyMix: blends two images using a matte/mask as the mix factor.
// result = mix(A, B, matte_channel * opacity)

uniform sampler2D texture_a : hint_default_white;
uniform sampler2D texture_b : hint_default_black;
uniform sampler2D matte_tex : hint_default_white;
uniform int matte_channel = 0; // 0=Luma, 1=R, 2=G, 3=B, 4=A
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform bool invert_matte = false;

void fragment() {
	vec4 a = texture(texture_a, UV);
	vec4 b = texture(texture_b, UV);
	vec4 m = texture(matte_tex, UV);

	float matte_val;
	switch (matte_channel) {
		case 1: matte_val = m.r; break;
		case 2: matte_val = m.g; break;
		case 3: matte_val = m.b; break;
		case 4: matte_val = m.a; break;
		default: matte_val = dot(m.rgb, vec3(0.2126, 0.7152, 0.0722)); break;
	}

	if (invert_matte) matte_val = 1.0 - matte_val;
	float factor = matte_val * opacity;
	COLOR = mix(a, b, factor);
}
