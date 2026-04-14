shader_type canvas_item;
// Grid warp — NxM bilinear grid deformation.
// Per-point offsets are passed as a uniform array; base UV, displacement
// texture sampling, and amplitude scaling all happen on the GPU.
// grid_offsets[y * grid_cols + x] = raw XY offset for that control point.

uniform sampler2D input_tex : filter_linear;
uniform int grid_cols = 4;
uniform int grid_rows = 4;
uniform float amplitude = 1.0;
// Max 8x8 = 64 control points.  Each stores raw offset (dx,dy) from params.
uniform vec2 grid_offsets[64];
// Optional displacement map — RG channels add offset (centred at 0.5).
uniform sampler2D disp_tex : filter_linear;
uniform bool has_disp = false;

void fragment() {
	float cell_w = 1.0 / float(grid_cols - 1);
	float cell_h = 1.0 / float(grid_rows - 1);

	int cx = int(floor(UV.x / cell_w));
	int cy = int(floor(UV.y / cell_h));
	cx = clamp(cx, 0, grid_cols - 2);
	cy = clamp(cy, 0, grid_rows - 2);

	float lx = (UV.x - float(cx) * cell_w) / cell_w;
	float ly = (UV.y - float(cy) * cell_h) / cell_h;

	// Base UVs for each cell corner
	vec2 base_tl = vec2(float(cx)     * cell_w, float(cy)     * cell_h);
	vec2 base_tr = vec2(float(cx + 1) * cell_w, float(cy)     * cell_h);
	vec2 base_bl = vec2(float(cx)     * cell_w, float(cy + 1) * cell_h);
	vec2 base_br = vec2(float(cx + 1) * cell_w, float(cy + 1) * cell_h);

	// Raw param offsets
	vec2 off_tl = grid_offsets[cy       * grid_cols + cx];
	vec2 off_tr = grid_offsets[cy       * grid_cols + cx + 1];
	vec2 off_bl = grid_offsets[(cy + 1) * grid_cols + cx];
	vec2 off_br = grid_offsets[(cy + 1) * grid_cols + cx + 1];

	// Displacement texture offsets (RG centered at 0.5)
	if (has_disp) {
		off_tl += texture(disp_tex, base_tl).rg - 0.5;
		off_tr += texture(disp_tex, base_tr).rg - 0.5;
		off_bl += texture(disp_tex, base_bl).rg - 0.5;
		off_br += texture(disp_tex, base_br).rg - 0.5;
	}

	// Final displaced positions (negated: offset moves the image, not the sample)
	vec2 p_tl = base_tl - off_tl * amplitude;
	vec2 p_tr = base_tr - off_tr * amplitude;
	vec2 p_bl = base_bl - off_bl * amplitude;
	vec2 p_br = base_br - off_br * amplitude;

	// Bilinear interpolation across the cell
	vec2 top_lerp = mix(p_tl, p_tr, lx);
	vec2 bot_lerp = mix(p_bl, p_br, lx);
	vec2 warped = mix(top_lerp, bot_lerp, ly);

	if (warped.x < 0.0 || warped.x > 1.0 || warped.y < 0.0 || warped.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(input_tex, warped);
	}
}
