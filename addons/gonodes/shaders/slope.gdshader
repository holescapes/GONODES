shader_type canvas_item;
// SlopeTOP — image gradient/derivative (dx, dy, magnitude).

uniform sampler2D source_tex : hint_default_white;
uniform int output_mode : hint_range(0, 2) = 0; // 0=Magnitude, 1=Horizontal (dx), 2=Vertical (dy)
uniform float strength = 1.0;

void fragment() {
	vec2 texel = vec2(1.0) / vec2(textureSize(source_tex, 0));

	vec3 left  = texture(source_tex, UV + vec2(-texel.x, 0.0)).rgb;
	vec3 right = texture(source_tex, UV + vec2( texel.x, 0.0)).rgb;
	vec3 up    = texture(source_tex, UV + vec2(0.0, -texel.y)).rgb;
	vec3 down  = texture(source_tex, UV + vec2(0.0,  texel.y)).rgb;

	vec3 dx = (right - left) * 0.5 * strength;
	vec3 dy = (down - up) * 0.5 * strength;

	if (output_mode == 0) {
		// Magnitude
		vec3 mag = sqrt(dx * dx + dy * dy);
		COLOR = vec4(mag, 1.0);
	} else if (output_mode == 1) {
		// Horizontal gradient — offset by 0.5 for signed display
		COLOR = vec4(dx + 0.5, 1.0);
	} else {
		// Vertical gradient — offset by 0.5 for signed display
		COLOR = vec4(dy + 0.5, 1.0);
	}
}
