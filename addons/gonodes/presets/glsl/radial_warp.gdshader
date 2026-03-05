// Radial warp — fisheye / barrel distortion with input texture
// uniform float strength : hint_range(-2.0, 2.0) = 0.5;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv);
	float factor = 1.0 + dist * dist * strength;
	vec2 warped = uv * factor + 0.5;

	if (warped.x < 0.0 || warped.x > 1.0 || warped.y < 0.0 || warped.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		COLOR = texture(gn_tex0, warped);
	}
}
