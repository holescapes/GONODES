shader_type canvas_item;
// UV displacement shader for DisplaceTOP.
// Uses a second texture to offset UV coordinates of the first.

uniform sampler2D source_tex : hint_default_white;
uniform sampler2D displace_tex : hint_default_black;
uniform float displace_weight = 0.1;
uniform int displace_method = 0; // 0=RG as XY, 1=luminance both, 2=RGB as XYZ(ignore Z)
uniform vec2 displace_scale = vec2(1.0, 1.0);

void fragment() {
	vec4 disp = texture(displace_tex, UV);

	vec2 offset;
	switch (displace_method) {
		case 0: // RG → XY
			offset = (disp.rg - 0.5) * 2.0;
			break;
		case 1: // Luminance → both axes
			float lum = dot(disp.rgb, vec3(0.2126, 0.7152, 0.0722));
			offset = vec2(lum - 0.5) * 2.0;
			break;
		case 2: // RGB as XYZ (ignore Z)
			offset = (disp.rg - 0.5) * 2.0;
			break;
		default:
			offset = vec2(0.0);
			break;
	}

	offset *= displace_scale * displace_weight;

	vec2 displaced_uv = UV + offset;
	COLOR = texture(source_tex, clamp(displaced_uv, vec2(0.0), vec2(1.0)));
}
