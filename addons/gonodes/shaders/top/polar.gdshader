shader_type canvas_item;
// Polar coordinate transform — Cartesian <-> Polar conversion.

uniform sampler2D source_tex : hint_default_white;
uniform int mode : hint_range(0, 1) = 0; // 0 = Cartesian to Polar, 1 = Polar to Cartesian
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	if (mode == 0) {
		// Cartesian → Polar
		vec2 uv = UV - center;
		float angle_val = atan(uv.y, uv.x);
		float dist = length(uv) * 2.0;
		// Map angle to X [0,1], distance to Y [0,1]
		float nx = (angle_val / 3.14159265 + 1.0) * 0.5;
		float ny = clamp(dist, 0.0, 1.0);
		COLOR = texture(source_tex, vec2(nx, ny));
	} else {
		// Polar → Cartesian
		float angle_val = (UV.x * 2.0 - 1.0) * 3.14159265;
		float dist = UV.y * 0.5;
		vec2 cart = vec2(cos(angle_val), sin(angle_val)) * dist + center;
		cart = clamp(cart, vec2(0.0), vec2(1.0));
		COLOR = texture(source_tex, cart);
	}
}
