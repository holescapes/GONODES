shader_type canvas_item;
// Ripple — animated sinusoidal wave distortion.

uniform sampler2D source_tex : hint_default_white;
uniform float amplitude : hint_range(0.0, 0.1) = 0.01;
uniform float frequency : hint_range(1.0, 100.0) = 20.0;
uniform float speed : hint_range(0.0, 20.0) = 5.0;
uniform float time_val : hint_range(0.0, 100000.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform int mode : hint_range(0, 1) = 0; // 0 = Radial, 1 = Directional

void fragment() {
	vec2 uv = UV;

	if (mode == 0) {
		// Radial ripple
		vec2 delta = UV - center;
		float dist = length(delta);
		float displacement = sin(dist * frequency - time_val * speed) * amplitude;
		vec2 dir = normalize(delta + vec2(0.0001));
		uv += dir * displacement;
	} else {
		// Directional ripple (horizontal)
		float displacement = sin(UV.y * frequency - time_val * speed) * amplitude;
		uv.x += displacement;
	}

	uv = clamp(uv, vec2(0.0), vec2(1.0));
	COLOR = texture(source_tex, uv);
}
