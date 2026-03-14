shader_type canvas_item;
// PatternTOP — procedural pattern generator: stripes, checkerboard, concentric, grid, dots.

uniform int pattern_type : hint_range(0, 4) = 0; // 0=Stripes, 1=Checkerboard, 2=Concentric, 3=Grid, 4=Dots
uniform float frequency = 8.0;
uniform float duty_cycle = 0.5;
uniform vec4 color_a : source_color = vec4(1.0);
uniform vec4 color_b : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float rotation = 0.0; // radians
uniform float softness = 0.02;

vec2 rotate_uv(vec2 uv, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	vec2 centered = uv - 0.5;
	return vec2(centered.x * c - centered.y * s, centered.x * s + centered.y * c) + 0.5;
}

void fragment() {
	vec2 uv = rotate_uv(UV, rotation);
	float val = 0.0;

	if (pattern_type == 0) {
		// Stripes (vertical)
		float t = fract(uv.x * frequency);
		val = smoothstep(duty_cycle - softness, duty_cycle + softness, t);
	} else if (pattern_type == 1) {
		// Checkerboard
		float cx = floor(uv.x * frequency);
		float cy = floor(uv.y * frequency);
		val = mod(cx + cy, 2.0);
	} else if (pattern_type == 2) {
		// Concentric circles
		float dist = length(uv - 0.5) * 2.0;
		float t = fract(dist * frequency);
		val = smoothstep(duty_cycle - softness, duty_cycle + softness, t);
	} else if (pattern_type == 3) {
		// Grid
		float tx = fract(uv.x * frequency);
		float ty = fract(uv.y * frequency);
		float gx = smoothstep(duty_cycle - softness, duty_cycle + softness, tx);
		float gy = smoothstep(duty_cycle - softness, duty_cycle + softness, ty);
		val = min(gx, gy);
	} else {
		// Dots
		vec2 cell = fract(uv * frequency);
		float dist = length(cell - 0.5);
		val = smoothstep(duty_cycle * 0.5 - softness, duty_cycle * 0.5 + softness, dist);
	}

	COLOR = mix(color_a, color_b, val);
}
