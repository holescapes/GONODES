shader_type canvas_item;
// Spherize / pinch distortion — bulge or pinch toward center.

uniform sampler2D source_tex : hint_default_white;
uniform float strength : hint_range(-2.0, 2.0) = 0.5;
uniform float radius : hint_range(0.01, 2.0) = 0.5;
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	vec2 uv = UV - center;
	float dist = length(uv);
	float norm_dist = dist / radius;

	if (norm_dist < 1.0) {
		float power = 1.0 - strength;
		float deformation = pow(norm_dist, max(power, 0.01)) / max(norm_dist, 0.0001);
		uv *= deformation;
	}

	vec2 new_uv = uv + center;
	new_uv = clamp(new_uv, vec2(0.0), vec2(1.0));
	COLOR = texture(source_tex, new_uv);
}
