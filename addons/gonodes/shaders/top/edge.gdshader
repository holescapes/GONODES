shader_type canvas_item;
// Sobel edge detection shader for EdgeTOP.

uniform sampler2D source_tex : hint_default_white;
uniform float strength : hint_range(0.0, 10.0) = 1.0;
uniform bool grayscale_input = true;

float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 texel = vec2(1.0) / vec2(textureSize(source_tex, 0));

	// Sample 3x3 neighborhood
	float tl = luminance(texture(source_tex, UV + vec2(-texel.x, -texel.y)).rgb);
	float tc = luminance(texture(source_tex, UV + vec2(0.0, -texel.y)).rgb);
	float tr = luminance(texture(source_tex, UV + vec2(texel.x, -texel.y)).rgb);
	float ml = luminance(texture(source_tex, UV + vec2(-texel.x, 0.0)).rgb);
	float mr = luminance(texture(source_tex, UV + vec2(texel.x, 0.0)).rgb);
	float bl = luminance(texture(source_tex, UV + vec2(-texel.x, texel.y)).rgb);
	float bc = luminance(texture(source_tex, UV + vec2(0.0, texel.y)).rgb);
	float br = luminance(texture(source_tex, UV + vec2(texel.x, texel.y)).rgb);

	// Sobel kernels
	float gx = -tl - 2.0 * ml - bl + tr + 2.0 * mr + br;
	float gy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;

	float edge = sqrt(gx * gx + gy * gy) * strength;

	if (grayscale_input) {
		COLOR = vec4(vec3(edge), 1.0);
	} else {
		vec4 col = texture(source_tex, UV);
		COLOR = vec4(col.rgb * edge, col.a);
	}
}
