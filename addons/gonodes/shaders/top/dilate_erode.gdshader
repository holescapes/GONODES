shader_type canvas_item;
// DilateErodeTOP — morphological dilation (expand) and erosion (shrink).

uniform sampler2D source_tex : hint_default_white;
uniform int mode : hint_range(0, 1) = 0; // 0=Dilate, 1=Erode
uniform int radius : hint_range(1, 16) = 2;

void fragment() {
	vec2 texel = vec2(1.0) / vec2(textureSize(source_tex, 0));
	vec4 result;

	if (mode == 0) {
		result = vec4(0.0); // Dilate: find maximum
	} else {
		result = vec4(1.0); // Erode: find minimum
	}

	for (int y = -radius; y <= radius; y++) {
		for (int x = -radius; x <= radius; x++) {
			// Circular footprint
			if (x * x + y * y > radius * radius) continue;

			vec2 uv = UV + vec2(float(x), float(y)) * texel;
			vec4 s = texture(source_tex, clamp(uv, vec2(0.0), vec2(1.0)));

			if (mode == 0) {
				result = max(result, s);
			} else {
				result = min(result, s);
			}
		}
	}

	COLOR = result;
}
