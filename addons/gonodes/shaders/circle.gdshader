shader_type canvas_item;
// SDF circle/ring generator for CircleTOP.

uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 center = vec2(0.5, 0.5);
uniform float radius = 0.4;
uniform float border_width = 0.0; // 0 = filled circle, >0 = ring
uniform float softness : hint_range(0.0, 0.1) = 0.005;

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = UV - center;
	uv.x *= aspect;
	vec2 c = vec2(0.0);

	float dist = length(uv - c);

	float shape;
	if (border_width > 0.0) {
		// Ring
		float outer = smoothstep(radius + softness, radius - softness, dist);
		float inner = smoothstep(radius - border_width - softness, radius - border_width + softness, dist);
		shape = outer * inner;
	} else {
		// Filled circle
		shape = smoothstep(radius + softness, radius - softness, dist);
	}

	COLOR = mix(bg_color, fill_color, shape);
}
