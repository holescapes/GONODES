shader_type canvas_item;
// Trail / echo effect — blends current frame with previous accumulated frame.

uniform sampler2D source_tex : hint_default_black;
uniform sampler2D prev_tex : hint_default_black;
uniform float decay : hint_range(0.0, 1.0) = 0.9;
uniform float brightness : hint_range(0.0, 5.0) = 1.0;

void fragment() {
	vec4 current = texture(source_tex, UV);
	vec4 previous = texture(prev_tex, UV);
	vec4 result = mix(current, previous, decay);
	result.rgb *= brightness;
	COLOR = vec4(result.rgb, max(current.a, result.a));
}
