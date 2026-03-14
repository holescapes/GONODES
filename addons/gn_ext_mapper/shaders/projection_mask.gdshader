shader_type canvas_item;
// Projection mask — multiplies input by a mask shape.
// Supports rectangular soft-edge mask with feather/falloff.

uniform sampler2D input_tex : filter_linear;
uniform float left = 0.0;    // Mask left edge (0-1 normalized)
uniform float right = 1.0;   // Mask right edge
uniform float top = 0.0;     // Mask top edge
uniform float bottom = 1.0;  // Mask bottom edge
uniform float feather = 0.02; // Soft edge width in UV space
uniform float invert = 0.0;  // 0.0 = normal, 1.0 = inverted mask

void fragment() {
	vec4 src = texture(input_tex, UV);

	// Distance from each edge (positive = inside)
	float dl = UV.x - left;
	float dr = right - UV.x;
	float dt = UV.y - top;
	float db = bottom - UV.y;

	float mask = 1.0;
	if (feather > 0.0) {
		mask *= smoothstep(0.0, feather, dl);
		mask *= smoothstep(0.0, feather, dr);
		mask *= smoothstep(0.0, feather, dt);
		mask *= smoothstep(0.0, feather, db);
	} else {
		// Hard edge
		if (dl < 0.0 || dr < 0.0 || dt < 0.0 || db < 0.0) {
			mask = 0.0;
		}
	}

	if (invert > 0.5) {
		mask = 1.0 - mask;
	}

	COLOR = vec4(src.rgb, src.a * mask);
}
