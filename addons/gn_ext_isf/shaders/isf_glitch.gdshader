shader_type canvas_item;
// ISF-style Glitch FX — random block displacement and color channel shift.

uniform vec2 isf_rendersize;
uniform sampler2D isf_inputImage;
uniform float intensity = 0.5;
uniform float block_size = 0.05;
uniform float color_shift = 0.02;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = floor(TIME * 10.0);

	// Block displacement
	float block_y = floor(uv.y / block_size) * block_size;
	float noise = rand(vec2(block_y, t));
	float threshold = 1.0 - intensity;
	float displacement = 0.0;
	if (noise > threshold) {
		displacement = (rand(vec2(block_y + 1.0, t)) - 0.5) * intensity * 0.3;
	}

	vec2 shifted_uv = uv + vec2(displacement, 0.0);

	// RGB channel separation
	float shift = color_shift * intensity;
	float r = texture(isf_inputImage, shifted_uv + vec2(shift, 0.0)).r;
	float g = texture(isf_inputImage, shifted_uv).g;
	float b = texture(isf_inputImage, shifted_uv - vec2(shift, 0.0)).b;
	float a = texture(isf_inputImage, shifted_uv).a;

	COLOR = vec4(r, g, b, a);
}
