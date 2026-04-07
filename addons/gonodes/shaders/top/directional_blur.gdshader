shader_type canvas_item;
// Directional blur — motion blur along an arbitrary angle.

uniform sampler2D source_tex : hint_default_white;
uniform float strength : hint_range(0.0, 100.0) = 10.0;
uniform float angle : hint_range(0.0, 360.0) = 0.0;
uniform int samples : hint_range(3, 64) = 16;

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(source_tex, 0));
	float rad = radians(angle);
	vec2 dir = vec2(cos(rad), sin(rad)) * texel * strength;

	vec4 accum = vec4(0.0);
	float total = 0.0;
	int half_samples = samples / 2;

	for (int i = -half_samples; i <= half_samples; i++) {
		float t = float(i) / float(half_samples);
		vec2 offset = dir * t;
		accum += texture(source_tex, UV + offset);
		total += 1.0;
	}

	COLOR = accum / total;
}
