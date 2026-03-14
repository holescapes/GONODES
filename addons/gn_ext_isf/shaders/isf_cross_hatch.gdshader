shader_type canvas_item;
// ISF-style Cross Hatch FX — pencil-sketch cross-hatching post-process.

uniform vec2 isf_rendersize;
uniform sampler2D isf_inputImage;
uniform float hatch_density = 10.0;
uniform float hatch_strength = 0.8;
uniform float brightness_threshold = 0.5;
uniform vec4 hatch_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 paper_color = vec4(0.95, 0.93, 0.88, 1.0);

void fragment() {
	vec4 src = texture(isf_inputImage, UV);
	float luma = dot(src.rgb, vec3(0.299, 0.587, 0.114));

	vec2 px = UV * isf_rendersize;
	float hatch = 0.0;

	// Diagonal hatching at different luminance thresholds
	if (luma < brightness_threshold) {
		float line1 = abs(sin((px.x + px.y) * hatch_density * 0.1));
		hatch = max(hatch, smoothstep(0.3, 0.0, line1));
	}
	if (luma < brightness_threshold * 0.66) {
		float line2 = abs(sin((px.x - px.y) * hatch_density * 0.1));
		hatch = max(hatch, smoothstep(0.3, 0.0, line2));
	}
	if (luma < brightness_threshold * 0.33) {
		float line3 = abs(sin(px.x * hatch_density * 0.14));
		hatch = max(hatch, smoothstep(0.3, 0.0, line3));
	}

	hatch *= hatch_strength;
	COLOR = mix(paper_color, hatch_color, hatch);
}
