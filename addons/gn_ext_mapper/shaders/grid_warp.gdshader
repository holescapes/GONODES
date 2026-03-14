shader_type canvas_item;
// Grid warp — NxM bilinear grid deformation.
// Control points are packed into a texture for arbitrary grid sizes.
// Each pixel in the grid texture stores the displaced UV (x, y) in RG channels.

uniform sampler2D input_tex : filter_linear;
uniform sampler2D grid_tex : filter_nearest;  // NxM grid of displaced positions
uniform int grid_cols = 4;  // Number of grid columns (control point columns)
uniform int grid_rows = 4;  // Number of grid rows (control point rows)

void fragment() {
	// Determine which grid cell this fragment falls in
	float cell_w = 1.0 / float(grid_cols - 1);
	float cell_h = 1.0 / float(grid_rows - 1);

	// Cell indices
	int cx = int(floor(UV.x / cell_w));
	int cy = int(floor(UV.y / cell_h));
	cx = clamp(cx, 0, grid_cols - 2);
	cy = clamp(cy, 0, grid_rows - 2);

	// Local coordinates within cell [0..1]
	float lx = (UV.x - float(cx) * cell_w) / cell_w;
	float ly = (UV.y - float(cy) * cell_h) / cell_h;

	// Sample the 4 corner control points from grid texture
	// Grid texture pixel centers: (col + 0.5) / grid_cols
	vec2 tl = texture(grid_tex, vec2((float(cx) + 0.5) / float(grid_cols), (float(cy) + 0.5) / float(grid_rows))).rg;
	vec2 tr = texture(grid_tex, vec2((float(cx + 1) + 0.5) / float(grid_cols), (float(cy) + 0.5) / float(grid_rows))).rg;
	vec2 bl = texture(grid_tex, vec2((float(cx) + 0.5) / float(grid_cols), (float(cy + 1) + 0.5) / float(grid_rows))).rg;
	vec2 br = texture(grid_tex, vec2((float(cx + 1) + 0.5) / float(grid_cols), (float(cy + 1) + 0.5) / float(grid_rows))).rg;

	// Bilinear interpolation of displaced position
	vec2 top_lerp = mix(tl, tr, lx);
	vec2 bot_lerp = mix(bl, br, lx);
	vec2 warped = mix(top_lerp, bot_lerp, ly);

	if (warped.x < 0.0 || warped.x > 1.0 || warped.y < 0.0 || warped.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(input_tex, warped);
	}
}
