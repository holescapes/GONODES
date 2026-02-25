shader_type canvas_item;
// 2D UV transform shader for TransformTOP.
// Applies translate, rotate, scale to UV coordinates.

uniform sampler2D source_tex : hint_default_white;
uniform vec2 translate = vec2(0.0, 0.0);
uniform float rotate_angle = 0.0; // radians
uniform vec2 scale_amount = vec2(1.0, 1.0);
uniform vec2 pivot = vec2(0.5, 0.5);
uniform int extend_mode = 0; // 0=clamp, 1=repeat, 2=mirror, 3=zero (black)

vec2 apply_extend(vec2 uv) {
	switch (extend_mode) {
		case 0: // Clamp
			return clamp(uv, vec2(0.0), vec2(1.0));
		case 1: // Repeat
			return fract(uv);
		case 2: // Mirror
			vec2 m = abs(mod(uv, 2.0) - 1.0);
			return m;
		case 3: // Zero
			return uv;
	}
	return uv;
}

void fragment() {
	vec2 uv = UV;

	// Move to pivot space
	uv -= pivot;

	// Scale
	uv /= max(scale_amount, vec2(0.0001));

	// Rotate
	float c = cos(rotate_angle);
	float s = sin(rotate_angle);
	uv = vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);

	// Translate
	uv -= translate;

	// Move back from pivot
	uv += pivot;

	// Extend mode
	vec2 final_uv = apply_extend(uv);

	// Zero mode: output black if out of bounds
	if (extend_mode == 3 && (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		COLOR = texture(source_tex, final_uv);
	}
}
