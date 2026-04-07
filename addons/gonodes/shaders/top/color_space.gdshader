shader_type canvas_item;
// Color space conversion shader for ColorSpaceTOP.
// Converts between sRGB, Linear, ACEScg, Rec.709 and Rec.2020.

uniform sampler2D source_tex : hint_default_white;
uniform int conversion = 0;
// 0 = sRGB → Linear
// 1 = Linear → sRGB
// 2 = sRGB → ACEScg
// 3 = ACEScg → sRGB
// 4 = Rec.709 → Rec.2020
// 5 = Rec.2020 → Rec.709

// sRGB EOTF (exact IEC 61966-2-1)
vec3 srgb_to_linear(vec3 c) {
	vec3 lo = c / 12.92;
	vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
	return mix(lo, hi, step(vec3(0.04045), c));
}

// sRGB inverse EOTF
vec3 linear_to_srgb(vec3 c) {
	vec3 lo = c * 12.92;
	vec3 hi = 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055;
	return mix(lo, hi, step(vec3(0.0031308), c));
}

// sRGB / Rec.709 primaries → ACEScg (AP1) 3x3 matrix
vec3 srgb_linear_to_acescg(vec3 c) {
	return vec3(
		0.6131 * c.r + 0.3395 * c.g + 0.0474 * c.b,
		0.0701 * c.r + 0.9164 * c.g + 0.0135 * c.b,
		0.0206 * c.r + 0.1096 * c.g + 0.8698 * c.b
	);
}

// ACEScg (AP1) → sRGB / Rec.709 primaries 3x3 matrix
vec3 acescg_to_srgb_linear(vec3 c) {
	return vec3(
		 1.7051 * c.r - 0.6218 * c.g - 0.0833 * c.b,
		-0.1302 * c.r + 1.1408 * c.g - 0.0106 * c.b,
		-0.0240 * c.r - 0.1290 * c.g + 1.1530 * c.b
	);
}

// Rec.709 → Rec.2020 3x3 matrix
vec3 rec709_to_rec2020(vec3 c) {
	return vec3(
		0.6274 * c.r + 0.3293 * c.g + 0.0433 * c.b,
		0.0691 * c.r + 0.9195 * c.g + 0.0114 * c.b,
		0.0164 * c.r + 0.0880 * c.g + 0.8956 * c.b
	);
}

// Rec.2020 → Rec.709 3x3 matrix
vec3 rec2020_to_rec709(vec3 c) {
	return vec3(
		 1.6605 * c.r - 0.5877 * c.g - 0.0728 * c.b,
		-0.1246 * c.r + 1.1329 * c.g - 0.0083 * c.b,
		-0.0182 * c.r - 0.1006 * c.g + 1.1187 * c.b
	);
}

void fragment() {
	vec4 s = texture(source_tex, UV);
	vec3 c = s.rgb;

	if (conversion == 0) {
		c = srgb_to_linear(c);
	} else if (conversion == 1) {
		c = linear_to_srgb(c);
	} else if (conversion == 2) {
		c = srgb_linear_to_acescg(srgb_to_linear(c));
	} else if (conversion == 3) {
		c = linear_to_srgb(acescg_to_srgb_linear(c));
	} else if (conversion == 4) {
		c = rec709_to_rec2020(c);
	} else if (conversion == 5) {
		c = rec2020_to_rec709(c);
	}

	COLOR = vec4(c, s.a);
}
