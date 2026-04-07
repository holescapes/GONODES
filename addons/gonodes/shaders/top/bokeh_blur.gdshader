shader_type canvas_item;
// Bokeh blur — shaped blur for depth-of-field look.
// Samples in a disc or hexagonal pattern.

uniform sampler2D source_tex : hint_default_white;
uniform float radius_px : hint_range(0.0, 64.0) = 8.0;
uniform int shape : hint_range(0, 1) = 0; // 0 = Disc, 1 = Hexagon
uniform int quality : hint_range(1, 8) = 3; // rings of samples
uniform float brightness : hint_range(0.0, 5.0) = 1.0;

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(source_tex, 0));
	vec4 accum = vec4(0.0);
	float total = 0.0;

	int rings = quality;

	for (int ring = 0; ring <= rings; ring++) {
		if (ring == 0) {
			accum += texture(source_tex, UV);
			total += 1.0;
		} else {
			float r = float(ring) / float(rings);
			int samples_in_ring = ring * 6; // 6 per ring for hex, also works for disc

			for (int s = 0; s < samples_in_ring; s++) {
				float ang = float(s) / float(samples_in_ring) * 6.28318;

				vec2 offset;
				if (shape == 1) {
					// Hexagonal: snap to hex grid
					float hex_side = floor(ang / 1.0472) * 1.0472; // PI/3
					float hex_frac = ang - hex_side;
					float hex_r = r * cos(1.0472 * 0.5) / max(cos(hex_frac - 1.0472 * 0.5), 0.001);
					offset = vec2(cos(ang), sin(ang)) * hex_r;
				} else {
					// Disc
					offset = vec2(cos(ang), sin(ang)) * r;
				}

				offset *= radius_px * texel;
				vec4 s_col = texture(source_tex, UV + offset);
				// Slight brightness weighting for bokeh highlight
				float w = 1.0 + max(dot(s_col.rgb, vec3(0.333)) - 0.5, 0.0) * (brightness - 1.0);
				accum += s_col * w;
				total += w;
			}
		}
	}

	COLOR = accum / total;
}
