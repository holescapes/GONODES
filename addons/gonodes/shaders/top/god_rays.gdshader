shader_type canvas_item;
// God rays (crepuscular rays / volumetric light) shader for GodRaysTOP.
// Iteratively samples toward a light source, accumulating bright pixels.

uniform sampler2D source_tex : hint_default_white;
uniform vec2 light_pos = vec2(0.5, 0.5);
uniform int num_samples = 64;
uniform float density = 1.0;
uniform float weight = 0.01;
uniform float decay = 0.97;
uniform float exposure = 1.0;
uniform float threshold = 0.5;

void fragment() {
	vec2 uv = UV;
	vec2 delta = uv - light_pos;
	delta *= density / float(num_samples);

	vec4 original = texture(source_tex, UV);

	// Start from current pixel, march toward light source
	vec4 accum = vec4(0.0);
	float illumination_decay = 1.0;
	vec2 sample_uv = uv;

	for (int i = 0; i < num_samples; i++) {
		sample_uv -= delta;
		vec4 s = texture(source_tex, clamp(sample_uv, vec2(0.0), vec2(1.0)));
		// Only accumulate bright pixels above threshold
		float luma = dot(s.rgb, vec3(0.2126, 0.7152, 0.0722));
		float mask = smoothstep(threshold, threshold + 0.1, luma);
		s.rgb *= mask;
		s *= illumination_decay * weight;
		accum += s;
		illumination_decay *= decay;
	}

	// Composite rays over original
	COLOR = vec4(original.rgb + accum.rgb * exposure, original.a);
}
