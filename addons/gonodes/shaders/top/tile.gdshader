shader_type canvas_item;
// Tile/repeat shader for TileTOP.

uniform sampler2D source_tex : hint_default_white;
uniform vec2 repeat_count = vec2(2.0, 2.0);
uniform vec2 tile_offset = vec2(0.0, 0.0);
uniform bool mirror_x = false;
uniform bool mirror_y = false;

void fragment() {
	vec2 uv = UV * repeat_count + tile_offset;

	if (mirror_x) {
		float mx = mod(uv.x, 2.0);
		uv.x = mx < 1.0 ? mx : 2.0 - mx;
	} else {
		uv.x = fract(uv.x);
	}

	if (mirror_y) {
		float my = mod(uv.y, 2.0);
		uv.y = my < 1.0 ? my : 2.0 - my;
	} else {
		uv.y = fract(uv.y);
	}

	COLOR = texture(source_tex, uv);
}
