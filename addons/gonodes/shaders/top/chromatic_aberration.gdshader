shader_type canvas_item;
// Chromatic aberration — offsets RGB channels radially or directionally.

uniform sampler2D source_tex : hint_default_white;
uniform float intensity : hint_range(0.0, 0.1) = 0.005;
uniform int mode : hint_range(0, 1) = 0; // 0 = Radial, 1 = Directional
uniform float angle : hint_range(0.0, 360.0) = 0.0;

void fragment() {
	vec2 center = vec2(0.5);
	vec2 offset;
	if (mode == 0) {
		// Radial: offset along vector from center
		offset = (UV - center) * intensity;
	} else {
		// Directional: offset along fixed angle
		float rad = radians(angle);
		offset = vec2(cos(rad), sin(rad)) * intensity;
	}

	float r = texture(source_tex, UV + offset).r;
	float g = texture(source_tex, UV).g;
	float b = texture(source_tex, UV - offset).b;
	float a = texture(source_tex, UV).a;

	COLOR = vec4(r, g, b, a);
}
