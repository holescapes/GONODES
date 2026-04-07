shader_type canvas_item;
// LumaBlurTOP — luminance-weighted selective blur.
// Bright or dark areas get more/less blur based on the luma threshold.

uniform float blur_size = 4.0;
uniform int quality : hint_range(1, 8) = 4;
uniform float luma_threshold = 0.5;
uniform bool blur_bright = true; // true=blur bright areas, false=blur dark areas

void fragment() {
	vec4 center = texture(TEXTURE, UV);
	float luma = dot(center.rgb, vec3(0.2126, 0.7152, 0.0722));

	float blur_factor;
	if (blur_bright) {
		blur_factor = smoothstep(luma_threshold - 0.1, luma_threshold + 0.1, luma);
	} else {
		blur_factor = 1.0 - smoothstep(luma_threshold - 0.1, luma_threshold + 0.1, luma);
	}

	if (blur_factor < 0.01) {
		COLOR = center;
	} else {
		vec2 texel = vec2(1.0) / vec2(textureSize(TEXTURE, 0));
		float effective_size = blur_size * blur_factor;
		vec4 result = vec4(0.0);
		float total_weight = 0.0;

		for (int i = -quality; i <= quality; i++) {
			for (int j = -quality; j <= quality; j++) {
				float w = 1.0 - length(vec2(float(i), float(j))) / float(quality + 1);
				if (w > 0.0) {
					vec2 uv = UV + vec2(float(i), float(j)) * texel * effective_size / float(quality);
					result += texture(TEXTURE, uv) * w;
					total_weight += w;
				}
			}
		}

		COLOR = result / total_weight;
	}
}
