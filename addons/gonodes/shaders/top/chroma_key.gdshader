shader_type canvas_item;
// ChromaKeyTOP — green-screen / luma key with spill suppression.

uniform sampler2D source_tex : hint_default_white;
uniform vec3 key_color : source_color = vec3(0.0, 1.0, 0.0);
uniform float threshold = 0.4;
uniform float smoothness = 0.08;
uniform float spill_reduction = 0.5;
uniform int key_mode : hint_range(0, 1) = 0; // 0 = Chroma, 1 = Luma

float rgb_distance(vec3 a, vec3 b) {
	vec3 d = a - b;
	return length(d);
}

void fragment() {
	vec4 col = texture(source_tex, UV);

	float alpha;
	if (key_mode == 0) {
		// Chroma key — distance from key color
		float dist = rgb_distance(col.rgb, key_color);
		alpha = smoothstep(threshold, threshold + smoothness, dist);
	} else {
		// Luma key — brightness threshold
		float lum = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
		float key_lum = dot(key_color, vec3(0.2126, 0.7152, 0.0722));
		float dist = abs(lum - key_lum);
		alpha = smoothstep(threshold, threshold + smoothness, dist);
	}

	// Spill suppression — reduce key color influence in semi-transparent areas
	vec3 spill_corrected = col.rgb;
	if (spill_reduction > 0.0) {
		float spill = max(0.0, 1.0 - alpha) * spill_reduction;
		// Find the dominant key channel and suppress it
		if (key_color.g > key_color.r && key_color.g > key_color.b) {
			spill_corrected.g = min(spill_corrected.g, max(spill_corrected.r, spill_corrected.b) + (1.0 - spill) * (spill_corrected.g - max(spill_corrected.r, spill_corrected.b)));
		} else if (key_color.b > key_color.r) {
			spill_corrected.b = min(spill_corrected.b, max(spill_corrected.r, spill_corrected.g) + (1.0 - spill) * (spill_corrected.b - max(spill_corrected.r, spill_corrected.g)));
		} else {
			spill_corrected.r = min(spill_corrected.r, max(spill_corrected.g, spill_corrected.b) + (1.0 - spill) * (spill_corrected.r - max(spill_corrected.g, spill_corrected.b)));
		}
	}

	COLOR = vec4(spill_corrected, col.a * alpha);
}
