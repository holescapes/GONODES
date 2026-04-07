shader_type canvas_item;
// Glitch effect — block displacement, channel shift, and color artifacts.

uniform sampler2D source_tex : hint_default_white;
uniform float block_size : hint_range(4.0, 128.0) = 32.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.3;
uniform float channel_shift : hint_range(0.0, 0.05) = 0.01;
uniform float time_val : hint_range(0.0, 100000.0) = 0.0;
uniform float speed : hint_range(0.1, 30.0) = 8.0;

float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 tex_size = vec2(textureSize(source_tex, 0));
	float time_q = floor(time_val * speed);

	// Block displacement
	vec2 block = floor(UV * tex_size / block_size);
	float rand_block = hash2(block + vec2(time_q));

	vec2 uv = UV;
	if (rand_block < intensity) {
		float offset_x = (hash2(block + vec2(time_q + 1.0)) * 2.0 - 1.0) * intensity * 0.1;
		uv.x += offset_x;
	}

	// Channel shift
	float shift = channel_shift * (hash2(vec2(floor(UV.y * tex_size.y / block_size), time_q)) * 2.0 - 1.0);

	float r = texture(source_tex, clamp(uv + vec2(shift, 0.0), vec2(0.0), vec2(1.0))).r;
	float g = texture(source_tex, clamp(uv, vec2(0.0), vec2(1.0))).g;
	float b = texture(source_tex, clamp(uv - vec2(shift, 0.0), vec2(0.0), vec2(1.0))).b;
	float a = texture(source_tex, uv).a;

	COLOR = vec4(r, g, b, a);
}
