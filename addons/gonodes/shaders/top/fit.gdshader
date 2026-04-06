shader_type canvas_item;
// FitTOP — aspect-aware resize: Fit, Fill, Stretch, Native.

uniform sampler2D source_tex : hint_default_white;
uniform int fit_mode : hint_range(0, 3) = 0; // 0=Fit, 1=Fill, 2=Stretch, 3=Native
uniform vec2 target_size = vec2(512.0, 512.0);
uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = UV;
	vec2 source_size = vec2(textureSize(source_tex, 0));

	if (fit_mode == 2) {
		// Stretch — direct mapping, ignore aspect
		COLOR = texture(source_tex, uv);
	} else {
		float src_aspect = source_size.x / source_size.y;
		float tgt_aspect = target_size.x / target_size.y;

		vec2 scale = vec2(1.0);
		vec2 offset = vec2(0.0);

		if (fit_mode == 0) {
			// Fit — scale to fit inside target, preserving aspect, border bars
			if (src_aspect > tgt_aspect) {
				scale.y = tgt_aspect / src_aspect;
			} else {
				scale.x = src_aspect / tgt_aspect;
			}
			offset = (vec2(1.0) - scale) * 0.5;
		} else if (fit_mode == 1) {
			// Fill — scale to cover target, may crop edges
			if (src_aspect > tgt_aspect) {
				scale.x = src_aspect / tgt_aspect;
			} else {
				scale.y = tgt_aspect / src_aspect;
			}
			offset = (vec2(1.0) - scale) * 0.5;
		} else {
			// Native — 1:1 pixel placement, no scaling
			scale = source_size / target_size;
			offset = (vec2(1.0) - scale) * 0.5;
		}

		vec2 mapped_uv = (uv - offset) / scale;

		if (mapped_uv.x < 0.0 || mapped_uv.x > 1.0 || mapped_uv.y < 0.0 || mapped_uv.y > 1.0) {
			COLOR = border_color;
		} else {
			COLOR = texture(source_tex, mapped_uv);
		}
	}
}
