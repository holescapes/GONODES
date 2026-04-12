shader_type canvas_item;
// Grid warp — NxM bilinear grid deformation.
// Control points are passed as a flat vec2 array of displaced UV positions.
// grid_points[y * grid_cols + x] = final UV for that control point.

uniform sampler2D input_tex : filter_linear;
uniform int grid_cols = 4;
uniform int grid_rows = 4;
// Max 8×8 = 64 control points.  Each stores the displaced UV (x,y).
uniform vec2 grid_points[64];

void fragment() {
	float cell_w = 1.0 / float(grid_cols - 1);
	float cell_h = 1.0 / float(grid_rows - 1);

	int cx = int(floor(UV.x / cell_w));
	int cy = int(floor(UV.y / cell_h));
	cx = clamp(cx, 0, grid_cols - 2);
	cy = clamp(cy, 0, grid_rows - 2);

	float lx = (UV.x - float(cx) * cell_w) / cell_w;
	float ly = (UV.y - float(cy) * cell_h) / cell_h;

	vec2 p_tl = grid_points[cy * grid_cols + cx];
	vec2 p_tr = grid_points[cy * grid_cols + cx + 1];
	vec2 p_bl = grid_points[(cy + 1) * grid_cols + cx];
	vec2 p_br = grid_points[(cy + 1) * grid_cols + cx + 1];

	vec2 top_lerp = mix(p_tl, p_tr, lx);
	vec2 bot_lerp = mix(p_bl, p_br, lx);
	vec2 warped = mix(top_lerp, bot_lerp, ly);

	if (warped.x < 0.0 || warped.x > 1.0 || warped.y < 0.0 || warped.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(input_tex, warped);
	}
}
