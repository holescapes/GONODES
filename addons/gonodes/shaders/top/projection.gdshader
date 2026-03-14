shader_type canvas_item;
// ProjectionTOP — UV projection mapping (planar, cylindrical, spherical).

uniform sampler2D source_tex : hint_default_white;
uniform int projection_mode : hint_range(0, 2) = 0; // 0=Planar, 1=Cylindrical, 2=Spherical
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform float rotation = 0.0;

void fragment() {
	vec2 uv = UV;

	// Apply rotation around center
	if (abs(rotation) > 0.001) {
		float c = cos(rotation);
		float s = sin(rotation);
		vec2 centered = uv - 0.5;
		uv = vec2(centered.x * c - centered.y * s, centered.x * s + centered.y * c) + 0.5;
	}

	if (projection_mode == 1) {
		// Cylindrical — wrap horizontal, linear vertical
		float angle = (uv.x - 0.5) * 3.14159265;
		uv.x = (sin(angle) + 1.0) * 0.5;
	} else if (projection_mode == 2) {
		// Spherical — UV from sphere coordinates
		vec2 centered = uv * 2.0 - 1.0;
		float r2 = dot(centered, centered);
		if (r2 > 1.0) {
			COLOR = vec4(0.0);
			return;
		}
		float z = sqrt(1.0 - r2);
		uv.x = atan(centered.x, z) / 3.14159265 + 0.5;
		uv.y = asin(centered.y) / 3.14159265 + 0.5;
	}

	// Apply scale and offset
	uv = uv * uv_scale + uv_offset;

	COLOR = texture(source_tex, uv);
}
