shader_type canvas_item;
// ProjectorBlend — multi-projector overlap luminance blending and color correction.
// Takes two projector inputs and composites them with gamma-corrected
// power-curve luminance ramps in the overlap region.
// Mimics TD's ProjectorBlend TOP for seamless multi-projector setups.

uniform sampler2D proj_a : filter_linear;  // Projector A (left/top)
uniform sampler2D proj_b : filter_linear;  // Projector B (right/bottom)

// Overlap region definition (in normalized UV of the output canvas)
uniform float overlap_start = 0.4;  // Where overlap begins (projector A starts fading)
uniform float overlap_end = 0.6;    // Where overlap ends (projector B finishes fading in)
uniform int blend_axis = 0;          // 0 = horizontal (left-right), 1 = vertical (top-bottom)

// Blend curve
uniform float blend_gamma = 2.2;    // Gamma for perceptually linear luminance blend
uniform float blend_exponent = 1.0; // Power curve exponent for blend shape (1=linear, 2=ease)

// Color correction (per-projector white point matching)
uniform vec3 color_a = vec3(1.0, 1.0, 1.0);  // Projector A color tint/correction
uniform vec3 color_b = vec3(1.0, 1.0, 1.0);  // Projector B color tint/correction
uniform float brightness_a = 1.0;  // Projector A brightness
uniform float brightness_b = 1.0;  // Projector B brightness

// Black level compensation
uniform float black_level = 0.0;  // Raised black level for overlap region (projector light adds)

void fragment() {
	vec4 a = texture(proj_a, UV);
	vec4 b = texture(proj_b, UV);

	// Apply per-projector color correction
	a.rgb *= color_a * brightness_a;
	b.rgb *= color_b * brightness_b;

	// Determine blend position along the chosen axis
	float pos = (blend_axis == 0) ? UV.x : UV.y;

	// Compute blend weights using gamma-corrected power curve
	float overlap_width = overlap_end - overlap_start;
	float t = 0.0;
	float weight_a = 1.0;
	float weight_b = 0.0;

	if (overlap_width > 0.001) {
		t = clamp((pos - overlap_start) / overlap_width, 0.0, 1.0);

		// Apply power curve for blend shape control
		float t_curved = pow(t, blend_exponent);

		// Gamma-correct the blend:
		// In overlap zone, we need both projectors to sum to perceived 1.0
		// Using complementary gamma-corrected weights ensures constant brightness
		weight_b = pow(t_curved, 1.0 / blend_gamma);
		weight_a = pow(1.0 - t_curved, 1.0 / blend_gamma);
	} else {
		// Sharp cut at midpoint
		float mid = (overlap_start + overlap_end) * 0.5;
		weight_a = step(pos, mid);  // 1 when pos <= mid
		weight_b = 1.0 - weight_a;
	}

	// Outside overlap: only one projector contributes
	if (pos < overlap_start) {
		weight_a = 1.0;
		weight_b = 0.0;
	} else if (pos > overlap_end) {
		weight_a = 0.0;
		weight_b = 1.0;
	}

	// Black level compensation in overlap region
	// Physical projectors add light — in overlap, black = 2x black level
	// We subtract it to maintain uniform black
	float in_overlap = step(overlap_start, pos) * step(pos, overlap_end);
	float black_comp = black_level * in_overlap;

	// Final composite
	vec3 result = a.rgb * weight_a + b.rgb * weight_b - vec3(black_comp);
	result = max(result, vec3(0.0));

	float alpha = max(a.a * weight_a, b.a * weight_b);
	COLOR = vec4(result, alpha);
}
