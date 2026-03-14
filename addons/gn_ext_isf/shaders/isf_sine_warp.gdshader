shader_type canvas_item;
// ISF-style Sine Warp generator — animated wave interference pattern.

uniform vec2 isf_rendersize;
uniform float speed = 1.0;
uniform float frequency = 10.0;
uniform float amplitude = 0.5;
uniform vec4 color1 = vec4(0.0, 0.2, 0.4, 1.0);
uniform vec4 color2 = vec4(0.9, 0.6, 0.1, 1.0);

void fragment() {
	vec2 uv = UV;
	float wave = sin(uv.x * frequency + TIME * speed) * amplitude;
	wave += sin(uv.y * frequency * 0.7 + TIME * speed * 1.3) * amplitude * 0.5;
	wave += sin((uv.x + uv.y) * frequency * 0.5 + TIME * speed * 0.8) * amplitude * 0.3;
	float t = wave * 0.5 + 0.5;
	COLOR = mix(color1, color2, t);
}
