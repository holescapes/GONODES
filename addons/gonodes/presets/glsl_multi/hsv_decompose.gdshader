shader_type canvas_item;

// --- HSV Decompose (Input Required) ---
// 4 outputs: original, hue, saturation, value.
// Tests a transform that produces meaningful per-channel results.

uniform sampler2D gn_tex0 : hint_default_white;

void fragment() {
	vec4 src = texture(gn_tex0, UV);
	vec3 rgb = src.rgb;

	// RGB -> HSV
	float cmax = max(rgb.r, max(rgb.g, rgb.b));
	float cmin = min(rgb.r, min(rgb.g, rgb.b));
	float delta = cmax - cmin;

	float h = 0.0;
	if (delta > 0.0001) {
		if (cmax == rgb.r)      h = mod((rgb.g - rgb.b) / delta, 6.0);
		else if (cmax == rgb.g) h = (rgb.b - rgb.r) / delta + 2.0;
		else                    h = (rgb.r - rgb.g) / delta + 4.0;
		h /= 6.0;
	}
	float s = (cmax > 0.0001) ? delta / cmax : 0.0;
	float v = cmax;

	gn_out0 = src;                         // Output 0: original
	gn_out1 = vec4(vec3(h), 1.0);         // Output 1: hue
	gn_out2 = vec4(vec3(s), 1.0);         // Output 2: saturation
	gn_out3 = vec4(vec3(v), 1.0);         // Output 3: value
}
