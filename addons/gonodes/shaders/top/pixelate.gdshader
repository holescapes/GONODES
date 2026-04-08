shader_type canvas_item;
// Pixelate / mosaic — snaps UV to a grid with configurable block shape.

uniform sampler2D source_tex : hint_default_white;
uniform float pixel_size : hint_range(1.0, 256.0) = 8.0;
uniform int shape : hint_range(0, 3) = 0; // 0=Square, 1=Circle, 2=Diamond, 3=Hexagon

void fragment() {
	vec2 tex_size = vec2(textureSize(source_tex, 0));
	vec2 grid = max(vec2(pixel_size), vec2(1.0));

	// Cell center in UV space
	vec2 cell = floor(UV * tex_size / grid);
	vec2 center_uv = (cell + 0.5) * grid / tex_size;
	vec4 center_color = texture(source_tex, center_uv);

	if (shape == 0) {
		// Square — standard mosaic
		COLOR = center_color;
	} else {
		// Position within cell, normalized to [-1, 1]
		vec2 cell_pos = fract(UV * tex_size / grid) * 2.0 - 1.0;
		float dist;

		if (shape == 1) {
			// Circle — Euclidean distance
			dist = length(cell_pos);
		} else if (shape == 2) {
			// Diamond — Manhattan distance
			dist = abs(cell_pos.x) + abs(cell_pos.y);
		} else {
			// Hexagon — hex distance approximation
			vec2 a = abs(cell_pos);
			dist = max(a.x * 0.866025 + a.y * 0.5, a.y);
		}

		// Inside shape = cell color, outside = transparent (reveals background)
		float mask = 1.0 - smoothstep(0.9, 1.0, dist);
		COLOR = vec4(center_color.rgb, center_color.a * mask);
	}
}
