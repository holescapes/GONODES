shader_type canvas_item;
// Crop shader for CropTOP.
// Selects a sub-region of the input texture.

uniform sampler2D source_tex : hint_default_white;
uniform vec2 crop_left_top = vec2(0.0, 0.0);     // normalized 0-1
uniform vec2 crop_right_bottom = vec2(1.0, 1.0);  // normalized 0-1

void fragment() {
	vec2 range = crop_right_bottom - crop_left_top;
	vec2 uv = crop_left_top + UV * range;
	COLOR = texture(source_tex, uv);
}
