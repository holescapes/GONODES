shader_type canvas_item;
// Simplified FXAA anti-aliasing — 3×3 neighbourhood, edge-perpendicular blur.

uniform sampler2D source_tex : hint_default_white;
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float edge_threshold : hint_range(0.0, 1.0) = 0.125;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(source_tex, 0));

	// Centre sample
	vec4 rgbaM = texture(source_tex, UV);
	vec3 rgbM  = rgbaM.rgb;
	float lumaM = luma(rgbM);

	// Cardinal neighbours
	float lumaN = luma(texture(source_tex, UV + vec2( 0.0,    -texel.y)).rgb);
	float lumaS = luma(texture(source_tex, UV + vec2( 0.0,     texel.y)).rgb);
	float lumaW = luma(texture(source_tex, UV + vec2(-texel.x,  0.0   )).rgb);
	float lumaE = luma(texture(source_tex, UV + vec2( texel.x,  0.0   )).rgb);

	// Early-out on low-contrast regions
	float luma_min   = min(lumaM, min(min(lumaN, lumaS), min(lumaW, lumaE)));
	float luma_max   = max(lumaM, max(max(lumaN, lumaS), max(lumaW, lumaE)));
	float luma_range = luma_max - luma_min;

	if (luma_range < edge_threshold) {
		COLOR = rgbaM;
	} else {
		// Diagonal neighbours (only fetched past the threshold)
		float lumaNW = luma(texture(source_tex, UV + vec2(-texel.x, -texel.y)).rgb);
		float lumaNE = luma(texture(source_tex, UV + vec2( texel.x, -texel.y)).rgb);
		float lumaSW = luma(texture(source_tex, UV + vec2(-texel.x,  texel.y)).rgb);
		float lumaSE = luma(texture(source_tex, UV + vec2( texel.x,  texel.y)).rgb);

		// Sobel edge direction ------------------------------------------------
		// edge_h high → horizontal edge (top row vs bottom row = vertical gradient)
		float edge_h = abs((lumaNW + 2.0 * lumaN + lumaNE) - (lumaSW + 2.0 * lumaS + lumaSE));
		// edge_v high → vertical edge (left col vs right col = horizontal gradient)
		float edge_v = abs((lumaNW + 2.0 * lumaW + lumaSW) - (lumaNE + 2.0 * lumaE + lumaSE));

		bool is_horizontal = edge_h >= edge_v;

		// Blend perpendicular to the edge to soften it.
		// Horizontal edge → sample vertically.  Vertical edge → sample horizontally.
		vec2 perp = is_horizontal ? vec2(0.0, texel.y) : vec2(texel.x, 0.0);

		vec3 rgbA = 0.5 * (
			texture(source_tex, UV + perp * strength).rgb +
			texture(source_tex, UV - perp * strength).rgb
		);

		// Sub-pixel aliasing factor (12-tap weighted average) -----------------
		float luma_avg = (1.0 / 12.0) * (
			2.0 * (lumaN + lumaS + lumaW + lumaE)
			+ lumaNW + lumaNE + lumaSW + lumaSE
		);
		float sub_pix = clamp(abs(lumaM - luma_avg) / luma_range, 0.0, 1.0);
		sub_pix = smoothstep(0.0, 1.0, sub_pix);

		// Final blend — minimum 25 % at edges so AA is always visible
		float blend = clamp(max(sub_pix, 0.25) * strength, 0.0, 1.0);

		COLOR = vec4(mix(rgbM, rgbA, blend), rgbaM.a);
	}
}
