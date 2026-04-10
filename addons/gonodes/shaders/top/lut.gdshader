shader_type canvas_item;
// LUT (Look-Up Table) colour grading shader.
// Applies a 3D texture LUT to remap input colours.

uniform sampler2D source_tex : hint_default_white;
uniform sampler3D lut_tex : filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 src = texture(source_tex, UV);
	vec3 graded = texture(lut_tex, src.rgb).rgb;
	COLOR = vec4(mix(src.rgb, graded, intensity), src.a);
}
