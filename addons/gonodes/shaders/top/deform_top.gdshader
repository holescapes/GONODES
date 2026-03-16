shader_type canvas_item;

uniform sampler2D source_tex : hint_default_white;
uniform sampler2D deform_tex : hint_default_black;
uniform float strength : hint_range(0.0, 1.0) = 0.1;
uniform int mode : hint_range(0, 2) = 0; // 0=Displace, 1=Refract, 2=Warp

void fragment() {
	vec2 uv = UV;
	vec4 deform = texture(deform_tex, uv);

	// Use RG channels as displacement vector
	vec2 offset = (deform.rg - 0.5) * 2.0 * strength;

	if (mode == 1) {
		// Refract: scale by luminance
		float luma = dot(deform.rgb, vec3(0.299, 0.587, 0.114));
		offset *= luma;
	} else if (mode == 2) {
		// Warp: polar displacement
		float angle = deform.r * TAU;
		float dist = deform.g * strength;
		offset = vec2(cos(angle), sin(angle)) * dist;
	}

	vec2 sample_uv = uv + offset;
	COLOR = texture(source_tex, sample_uv);
}
