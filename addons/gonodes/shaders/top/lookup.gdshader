shader_type canvas_item;
// Lookup / color grading shader for LookupTOP.
// Uses luminance of the source to index into a ramp/LUT texture.

uniform sampler2D source_tex : hint_default_white;
uniform sampler2D lookup_tex : hint_default_white; // 1D ramp or LUT
uniform int lookup_channel = 0; // 0=luminance, 1=red, 2=green, 3=blue
uniform float mix_amount : hint_range(0.0, 1.0) = 1.0;

float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec4 col = texture(source_tex, UV);

	float index_val;
	switch (lookup_channel) {
		case 0: index_val = luminance(col.rgb); break;
		case 1: index_val = col.r; break;
		case 2: index_val = col.g; break;
		case 3: index_val = col.b; break;
		default: index_val = luminance(col.rgb); break;
	}

	vec4 looked_up = texture(lookup_tex, vec2(index_val, 0.5));
	COLOR = mix(col, looked_up, mix_amount);
}
