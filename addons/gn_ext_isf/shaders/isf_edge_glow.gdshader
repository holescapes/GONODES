shader_type canvas_item;
// ISF-style Edge Glow FX — edge detection with colored glow overlay.

uniform vec2 isf_rendersize;
uniform sampler2D isf_inputImage;
uniform float edge_strength = 2.0;
uniform float glow_amount = 0.5;
uniform vec4 glow_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform bool show_original = true;

void fragment() {
	vec2 px = 1.0 / isf_rendersize;

	// Sobel edge detection
	vec3 tl = texture(isf_inputImage, UV + vec2(-px.x, -px.y)).rgb;
	vec3 tc = texture(isf_inputImage, UV + vec2( 0.0,  -px.y)).rgb;
	vec3 tr = texture(isf_inputImage, UV + vec2( px.x, -px.y)).rgb;
	vec3 ml = texture(isf_inputImage, UV + vec2(-px.x,  0.0)).rgb;
	vec3 mr = texture(isf_inputImage, UV + vec2( px.x,  0.0)).rgb;
	vec3 bl = texture(isf_inputImage, UV + vec2(-px.x,  px.y)).rgb;
	vec3 bc = texture(isf_inputImage, UV + vec2( 0.0,   px.y)).rgb;
	vec3 br = texture(isf_inputImage, UV + vec2( px.x,  px.y)).rgb;

	vec3 gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
	vec3 gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
	float edge = length(gx) + length(gy);
	edge = clamp(edge * edge_strength, 0.0, 1.0);

	vec4 src = texture(isf_inputImage, UV);
	vec4 glow = glow_color * edge * glow_amount;

	if (show_original)
		COLOR = src + glow;
	else
		COLOR = vec4(glow_color.rgb * edge, 1.0);
}
