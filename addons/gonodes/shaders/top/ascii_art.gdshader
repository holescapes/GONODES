shader_type canvas_item;
// ASCII art — render image as text characters using a font atlas.
// Divides the image into cells and picks a character based on brightness.

uniform sampler2D source_tex : hint_default_white;
uniform float cell_size : hint_range(4.0, 32.0) = 8.0;
uniform vec4 text_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool color_mode = false;

// 10-level ASCII density ramp encoded as 5x5 pixel patterns
// Characters (dark to bright): " " "." ":" "-" "=" "+" "*" "#" "%" "@"
float get_char_pixel(int char_idx, ivec2 local) {
	// Simplified: generate distinctive patterns for each density level
	int lx = local.x;
	int ly = local.y;

	if (char_idx == 0) return 0.0;  // space
	if (char_idx == 1) return (lx == 2 && ly == 3) ? 1.0 : 0.0;  // .
	if (char_idx == 2) return ((lx == 2 && ly == 1) || (lx == 2 && ly == 3)) ? 1.0 : 0.0;  // :
	if (char_idx == 3) return (ly == 2 && lx >= 1 && lx <= 3) ? 1.0 : 0.0;  // -
	if (char_idx == 4) return ((ly == 1 || ly == 3) && lx >= 1 && lx <= 3) ? 1.0 : 0.0;  // =
	if (char_idx == 5) return ((lx == 2 && ly >= 1 && ly <= 3) || (ly == 2 && lx >= 1 && lx <= 3)) ? 1.0 : 0.0;  // +
	if (char_idx == 6) {  // *
		return ((lx == 2 && ly >= 0 && ly <= 4) || (ly == 2 && lx >= 0 && lx <= 4)
			|| (lx == ly) || (lx + ly == 4)) ? 1.0 : 0.0;
	}
	if (char_idx == 7) {  // #
		return ((lx == 1 || lx == 3) || (ly == 1 || ly == 3)) ? 1.0 : 0.0;
	}
	if (char_idx == 8) {  // %
		return ((lx + ly) % 2 == 0) ? 1.0 : 0.0;
	}
	// idx >= 9: @
	return ((lx >= 1 && lx <= 3 && ly >= 1 && ly <= 3) || lx == 0 || lx == 4 || ly == 0 || ly == 4) ? 1.0 : 0.0;
}

void fragment() {
	vec2 tex_size = vec2(textureSize(source_tex, 0));
	vec2 pixel_coord = UV * tex_size;
	vec2 cell = floor(pixel_coord / cell_size);
	vec2 cell_center = (cell + 0.5) * cell_size / tex_size;

	// Sample average color of the cell
	vec4 avg = texture(source_tex, cell_center);
	float luma = dot(avg.rgb, vec3(0.2126, 0.7152, 0.0722));

	// Map luminance to character index (0-9)
	int char_idx = int(clamp(luma * 10.0, 0.0, 9.0));

	// Local position within cell (0-4 for 5x5 character grid)
	ivec2 local = ivec2(mod(pixel_coord, vec2(cell_size)) / (cell_size / 5.0));
	local = clamp(local, ivec2(0), ivec2(4));

	float pixel_val = get_char_pixel(char_idx, local);

	vec3 fg;
	if (color_mode) {
		fg = avg.rgb * text_color.rgb;
	} else {
		fg = text_color.rgb;
	}

	vec3 result = mix(bg_color.rgb, fg, pixel_val);
	COLOR = vec4(result, 1.0);
}
