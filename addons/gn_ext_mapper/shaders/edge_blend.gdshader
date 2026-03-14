shader_type canvas_item;
// Edge blend — soft-edge gradient for multi-projector overlap zones.
// Applies a smooth falloff on each edge (left, right, top, bottom).

uniform float blend_left = 0.0;
uniform float blend_right = 0.0;
uniform float blend_top = 0.0;
uniform float blend_bottom = 0.0;
uniform float gamma = 2.2;
uniform sampler2D input_tex : filter_linear;

void fragment() {
	vec4 col = texture(input_tex, UV);

	float alpha = 1.0;

	// Left edge blend
	if (blend_left > 0.0 && UV.x < blend_left) {
		alpha *= pow(UV.x / blend_left, gamma);
	}

	// Right edge blend
	if (blend_right > 0.0 && UV.x > (1.0 - blend_right)) {
		alpha *= pow((1.0 - UV.x) / blend_right, gamma);
	}

	// Top edge blend
	if (blend_top > 0.0 && UV.y < blend_top) {
		alpha *= pow(UV.y / blend_top, gamma);
	}

	// Bottom edge blend
	if (blend_bottom > 0.0 && UV.y > (1.0 - blend_bottom)) {
		alpha *= pow((1.0 - UV.y) / blend_bottom, gamma);
	}

	COLOR = vec4(col.rgb * alpha, col.a * alpha);
}
