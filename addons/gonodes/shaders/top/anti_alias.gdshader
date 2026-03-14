shader_type canvas_item;
// Simplified FXAA anti-aliasing shader.

uniform sampler2D source_tex : hint_default_white;
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float edge_threshold : hint_range(0.0, 1.0) = 0.125;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 texel = vec2(1.0) / vec2(textureSize(source_tex, 0));

	// Sample center and 4 neighbors
	vec3 rgbM  = texture(source_tex, UV).rgb;
	vec3 rgbN  = texture(source_tex, UV + vec2(0.0, -texel.y)).rgb;
	vec3 rgbS  = texture(source_tex, UV + vec2(0.0,  texel.y)).rgb;
	vec3 rgbW  = texture(source_tex, UV + vec2(-texel.x, 0.0)).rgb;
	vec3 rgbE  = texture(source_tex, UV + vec2( texel.x, 0.0)).rgb;

	float lumaM = luma(rgbM);
	float lumaN = luma(rgbN);
	float lumaS = luma(rgbS);
	float lumaW = luma(rgbW);
	float lumaE = luma(rgbE);

	float luma_min = min(lumaM, min(min(lumaN, lumaS), min(lumaW, lumaE)));
	float luma_max = max(lumaM, max(max(lumaN, lumaS), max(lumaW, lumaE)));
	float luma_range = luma_max - luma_min;

	// Skip pixels with low contrast
	if (luma_range < edge_threshold) {
		COLOR = vec4(rgbM, 1.0);
		return;
	}

	// Determine edge direction
	float edge_h = abs(-2.0 * lumaW + (lumaN + lumaS)) + abs(-2.0 * lumaE + (lumaN + lumaS));
	float edge_v = abs(-2.0 * lumaN + (lumaW + lumaE)) + abs(-2.0 * lumaS + (lumaW + lumaE));
	bool is_horizontal = edge_h >= edge_v;

	// Blend along edge direction
	vec2 blend_dir;
	if (is_horizontal) {
		blend_dir = vec2(texel.x, 0.0);
	} else {
		blend_dir = vec2(0.0, texel.y);
	}

	vec3 rgbA = 0.5 * (
		texture(source_tex, UV - blend_dir * strength).rgb +
		texture(source_tex, UV + blend_dir * strength).rgb
	);

	// Sub-pixel aliasing factor
	float sub_pixel = clamp(abs(lumaM - 0.25 * (lumaN + lumaS + lumaW + lumaE)) / luma_range, 0.0, 1.0);
	float blend_factor = smoothstep(0.0, 1.0, sub_pixel) * 0.75 * strength;

	COLOR = vec4(mix(rgbM, rgbA, blend_factor), 1.0);
}
