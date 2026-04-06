shader_type canvas_item;
// Crop shader for CropTOP.
// Selects a sub-region of the input texture with configurable edge mode.

uniform sampler2D source_tex : hint_default_white;
uniform vec2 crop_left_top = vec2(0.0, 0.0);     // normalized 0-1
uniform vec2 crop_right_bottom = vec2(1.0, 1.0);  // normalized 0-1
uniform int edge_mode : hint_range(0, 3) = 0;    // 0=Clamp, 1=Repeat, 2=Mirror, 3=Zero

void fragment() {
	vec2 range_uv = crop_right_bottom - crop_left_top;
	vec2 uv = crop_left_top + UV * range_uv;

	if (edge_mode == 0) {
		// Clamp — clamp to source [0,1]
		uv = clamp(uv, vec2(0.0), vec2(1.0));
		COLOR = texture(source_tex, uv);
	} else if (edge_mode == 1) {
		// Repeat — tile
		uv = fract(uv);
		COLOR = texture(source_tex, uv);
	} else if (edge_mode == 2) {
		// Mirror — ping-pong
		uv = abs(mod(uv, vec2(2.0)) - vec2(1.0));
		uv = vec2(1.0) - uv;
		COLOR = texture(source_tex, uv);
	} else {
		// Zero — transparent outside [0,1]
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			COLOR = vec4(0.0);
		} else {
			COLOR = texture(source_tex, uv);
		}
	}
}
