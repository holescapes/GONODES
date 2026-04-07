shader_type canvas_item;
// Toon / cel shading — quantized shading levels + Sobel outline.

uniform sampler2D source_tex : hint_default_white;
uniform int shade_levels : hint_range(2, 16) = 4;
uniform float edge_strength : hint_range(0.0, 5.0) = 1.5;
uniform float edge_threshold : hint_range(0.0, 1.0) = 0.1;
uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(source_tex, 0));
	vec4 src = texture(source_tex, UV);

	// Quantize color levels
	float n = float(shade_levels) - 1.0;
	vec3 quantized = floor(src.rgb * n + 0.5) / n;

	// Sobel edge detection
	float tl = luminance(texture(source_tex, UV + vec2(-texel.x, -texel.y)).rgb);
	float tc = luminance(texture(source_tex, UV + vec2(0.0, -texel.y)).rgb);
	float tr = luminance(texture(source_tex, UV + vec2(texel.x, -texel.y)).rgb);
	float ml = luminance(texture(source_tex, UV + vec2(-texel.x, 0.0)).rgb);
	float mr = luminance(texture(source_tex, UV + vec2(texel.x, 0.0)).rgb);
	float bl = luminance(texture(source_tex, UV + vec2(-texel.x, texel.y)).rgb);
	float bc = luminance(texture(source_tex, UV + vec2(0.0, texel.y)).rgb);
	float br = luminance(texture(source_tex, UV + vec2(texel.x, texel.y)).rgb);

	float gx = -tl - 2.0 * ml - bl + tr + 2.0 * mr + br;
	float gy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;
	float edge = sqrt(gx * gx + gy * gy) * edge_strength;

	float edge_mask = smoothstep(edge_threshold, edge_threshold + 0.1, edge);
	vec3 result = mix(quantized, edge_color.rgb, edge_mask * edge_color.a);

	COLOR = vec4(result, src.a);
}
