shader_type canvas_item;
// Spatial frequency filter — Low Pass, High Pass, or Band Pass.
// Uses a two-pass box blur approximation in a single pass for simplicity.
// Low Pass = blur, High Pass = original - blur + offset,
// Band Pass = blur(r_inner) - blur(r_outer): isolates a frequency band.

uniform sampler2D source_tex : hint_default_white;
uniform int mode : hint_range(0, 2) = 0; // 0=Low Pass, 1=High Pass, 2=Band Pass
uniform float radius : hint_range(1.0, 50.0) = 5.0;
uniform float radius_outer : hint_range(1.0, 80.0) = 15.0; // Band Pass only: outer radius
uniform float strength : hint_range(0.0, 5.0) = 1.0;
uniform float offset : hint_range(0.0, 1.0) = 0.5; // HP/BP mid-gray offset

vec3 box_blur(vec2 uv, float r) {
	vec2 texel = 1.0 / vec2(textureSize(source_tex, 0));
	int ri = int(r);
	vec3 sum = vec3(0.0);
	float count = 0.0;
	for (int dy = -ri; dy <= ri; dy++) {
		for (int dx = -ri; dx <= ri; dx++) {
			sum += texture(source_tex, uv + vec2(float(dx), float(dy)) * texel).rgb;
			count += 1.0;
		}
	}
	return sum / count;
}

void fragment() {
	vec3 original = texture(source_tex, UV).rgb;
	float alpha_val = texture(source_tex, UV).a;
	vec3 result;

	if (mode == 0) {
		// Low Pass — just the blur
		result = box_blur(UV, radius);
	} else if (mode == 1) {
		// High Pass — original minus blur, shifted to mid-gray
		vec3 blurred = box_blur(UV, radius);
		result = (original - blurred) * strength + vec3(offset);
	} else {
		// Band Pass — blur(inner) minus blur(outer)
		// Inner (smaller radius) retains more detail,
		// outer (larger radius) is smoother — difference = the frequency band between them.
		vec3 inner = box_blur(UV, radius);
		vec3 outer = box_blur(UV, radius_outer);
		result = (inner - outer) * strength + vec3(offset);
	}

	result = clamp(result, vec3(0.0), vec3(1.0));
	COLOR = vec4(result, alpha_val);
}
