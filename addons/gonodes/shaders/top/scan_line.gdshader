shader_type canvas_item;
// CRT / VHS scan line effect with optional jitter.

uniform sampler2D source_tex : hint_default_white;
uniform float line_spacing : hint_range(1.0, 20.0) = 4.0;
uniform float line_brightness : hint_range(0.0, 1.0) = 0.5;
uniform float jitter : hint_range(0.0, 10.0) = 0.0;
uniform float time_val : hint_range(0.0, 100000.0) = 0.0;
uniform float curvature : hint_range(0.0, 0.5) = 0.0;

float hash1(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// CRT curvature
	if (curvature > 0.0) {
		vec2 cc = uv - 0.5;
		float dist = dot(cc, cc);
		uv = uv + cc * dist * curvature;
	}

	// Horizontal jitter per scanline
	if (jitter > 0.0) {
		float line_id = floor(uv.y * vec2(textureSize(source_tex, 0)).y / line_spacing);
		float jit = (hash1(line_id + floor(time_val * 30.0)) * 2.0 - 1.0) * jitter / vec2(textureSize(source_tex, 0)).x;
		uv.x += jit;
	}

	vec4 src = texture(source_tex, clamp(uv, vec2(0.0), vec2(1.0)));
	float pixel_y = uv.y * vec2(textureSize(source_tex, 0)).y;
	float line_mask = 1.0 - (1.0 - line_brightness) * step(0.5, fract(pixel_y / line_spacing));

	COLOR = vec4(src.rgb * line_mask, src.a);
}
