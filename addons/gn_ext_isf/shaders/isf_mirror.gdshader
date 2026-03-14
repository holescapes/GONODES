shader_type canvas_item;
// ISF-style Mirror FX — horizontal/vertical/quad mirror.

uniform vec2 isf_rendersize;
uniform sampler2D isf_inputImage;
uniform int mirror_mode = 0; // 0=Horizontal, 1=Vertical, 2=Quad
uniform float mirror_pos = 0.5;

void fragment() {
	vec2 uv = UV;

	if (mirror_mode == 0 || mirror_mode == 2) {
		// Horizontal mirror
		if (uv.x > mirror_pos)
			uv.x = mirror_pos - (uv.x - mirror_pos);
	}
	if (mirror_mode == 1 || mirror_mode == 2) {
		// Vertical mirror
		if (uv.y > mirror_pos)
			uv.y = mirror_pos - (uv.y - mirror_pos);
	}

	COLOR = texture(isf_inputImage, clamp(uv, vec2(0.0), vec2(1.0)));
}
