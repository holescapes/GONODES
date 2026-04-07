shader_type canvas_item;
// Vignette — darken or tint edges with configurable falloff.

uniform sampler2D source_tex : hint_default_white;
uniform float intensity : hint_range(0.0, 2.0) = 0.5;
uniform float softness : hint_range(0.01, 2.0) = 0.5;
uniform float roundness : hint_range(0.0, 1.0) = 1.0;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec4 src = texture(source_tex, UV);
	vec2 center = UV - vec2(0.5);
	// Ellipse factor: roundness=1 gives circle, <1 stretches horizontally
	center.x *= mix(1.0, 1.0, roundness);
	float dist = length(center) * 2.0;
	float vignette = smoothstep(1.0 - softness, 1.0, dist * intensity);
	src.rgb = mix(src.rgb, color.rgb, vignette * color.a);
	COLOR = src;
}
