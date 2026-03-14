shader_type canvas_item;
// LensDistortTOP — barrel/pincushion/fisheye distortion.

uniform sampler2D source_tex : hint_default_white;
uniform float k1 = 0.2; // Radial distortion coefficient (+ barrel, - pincushion)
uniform float k2 = 0.0; // Higher-order distortion
uniform float chromatic_aberration = 0.0; // Separate RGB channels slightly
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);

vec2 distort_uv(vec2 uv, float k1_val, float k2_val) {
	vec2 centered = uv * 2.0 - 1.0;
	float r2 = dot(centered, centered);
	float r4 = r2 * r2;
	float factor = 1.0 + k1_val * r2 + k2_val * r4;
	vec2 distorted = centered * factor;
	return distorted * 0.5 + 0.5;
}

void fragment() {
	if (chromatic_aberration > 0.001) {
		// Per-channel distortion for chromatic aberration
		float offset = chromatic_aberration * 0.01;
		vec2 uv_r = distort_uv(UV, k1 + offset, k2);
		vec2 uv_g = distort_uv(UV, k1, k2);
		vec2 uv_b = distort_uv(UV, k1 - offset, k2);

		float r = (uv_r.x >= 0.0 && uv_r.x <= 1.0 && uv_r.y >= 0.0 && uv_r.y <= 1.0) ? texture(source_tex, uv_r).r : bg_color.r;
		float g = (uv_g.x >= 0.0 && uv_g.x <= 1.0 && uv_g.y >= 0.0 && uv_g.y <= 1.0) ? texture(source_tex, uv_g).g : bg_color.g;
		float b = (uv_b.x >= 0.0 && uv_b.x <= 1.0 && uv_b.y >= 0.0 && uv_b.y <= 1.0) ? texture(source_tex, uv_b).b : bg_color.b;

		float a = (uv_g.x >= 0.0 && uv_g.x <= 1.0 && uv_g.y >= 0.0 && uv_g.y <= 1.0) ? texture(source_tex, uv_g).a : bg_color.a;
		COLOR = vec4(r, g, b, a);
	} else {
		vec2 uv = distort_uv(UV, k1, k2);
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			COLOR = bg_color;
		} else {
			COLOR = texture(source_tex, uv);
		}
	}
}
