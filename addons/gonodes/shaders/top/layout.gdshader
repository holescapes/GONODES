shader_type canvas_item;
// LayoutTOP — tile N textures into a grid mosaic.
// Supports up to 8 inputs via a texture array workaround.
// Each grid cell maps to an input texture by index.

uniform sampler2D tex0 : hint_default_black;
uniform sampler2D tex1 : hint_default_black;
uniform sampler2D tex2 : hint_default_black;
uniform sampler2D tex3 : hint_default_black;
uniform sampler2D tex4 : hint_default_black;
uniform sampler2D tex5 : hint_default_black;
uniform sampler2D tex6 : hint_default_black;
uniform sampler2D tex7 : hint_default_black;
uniform int num_inputs : hint_range(1, 8) = 2;
uniform int columns : hint_range(1, 8) = 2;
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec4 sample_input(int idx, vec2 uv) {
	if (idx == 0) return texture(tex0, uv);
	else if (idx == 1) return texture(tex1, uv);
	else if (idx == 2) return texture(tex2, uv);
	else if (idx == 3) return texture(tex3, uv);
	else if (idx == 4) return texture(tex4, uv);
	else if (idx == 5) return texture(tex5, uv);
	else if (idx == 6) return texture(tex6, uv);
	else if (idx == 7) return texture(tex7, uv);
	return vec4(0.0);
}

void fragment() {
	int rows = (num_inputs + columns - 1) / columns;
	float cell_w = 1.0 / float(columns);
	float cell_h = 1.0 / float(rows);

	int col = int(floor(UV.x / cell_w));
	int row = int(floor(UV.y / cell_h));
	int idx = row * columns + col;

	if (idx >= num_inputs) {
		COLOR = bg_color;
		return;
	}

	vec2 cell_uv = vec2(
		(UV.x - float(col) * cell_w) / cell_w,
		(UV.y - float(row) * cell_h) / cell_h
	);

	COLOR = sample_input(idx, cell_uv);
}
