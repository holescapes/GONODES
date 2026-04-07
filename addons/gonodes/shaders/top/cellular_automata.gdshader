shader_type canvas_item;
// Cellular automata — Game of Life and variants with ping-pong feedback.

uniform sampler2D source_tex : hint_default_black;
uniform sampler2D prev_state : hint_default_black;
uniform int rule_set : hint_range(0, 3) = 0; // 0=Life, 1=Brian's Brain, 2=Seeds, 3=Day & Night
uniform bool reset = false;
uniform float threshold : hint_range(0.0, 1.0) = 0.5;

float get_cell(vec2 uv) {
	return step(threshold, dot(texture(prev_state, uv).rgb, vec3(0.333)));
}

void fragment() {
	if (reset) {
		// Use source as initial seed pattern
		vec4 src = texture(source_tex, UV);
		float alive = step(threshold, dot(src.rgb, vec3(0.333)));
		COLOR = vec4(vec3(alive), 1.0);
	} else {
		vec2 texel = 1.0 / vec2(textureSize(prev_state, 0));

		// Count 8 neighbors
		float n = 0.0;
		n += get_cell(UV + vec2(-texel.x, -texel.y));
		n += get_cell(UV + vec2(0.0, -texel.y));
		n += get_cell(UV + vec2(texel.x, -texel.y));
		n += get_cell(UV + vec2(-texel.x, 0.0));
		n += get_cell(UV + vec2(texel.x, 0.0));
		n += get_cell(UV + vec2(-texel.x, texel.y));
		n += get_cell(UV + vec2(0.0, texel.y));
		n += get_cell(UV + vec2(texel.x, texel.y));

		float self_val = get_cell(UV);
		float new_val = 0.0;

		if (rule_set == 0) {
			// Conway's Game of Life: B3/S23
			if (self_val > 0.5) {
				new_val = (n >= 2.0 && n <= 3.0) ? 1.0 : 0.0;
			} else {
				new_val = (n >= 2.5 && n <= 3.5) ? 1.0 : 0.0;
			}
		} else if (rule_set == 1) {
			// Brian's Brain: 3 states (alive=1, dying=0.5, dead=0)
			float raw = dot(texture(prev_state, UV).rgb, vec3(0.333));
			if (raw > 0.75) {
				new_val = 0.5; // alive → dying
			} else if (raw > 0.25 && raw < 0.75) {
				new_val = 0.0; // dying → dead
			} else {
				new_val = (n >= 2.0 && n <= 2.5) ? 1.0 : 0.0; // dead → alive if exactly 2
			}
		} else if (rule_set == 2) {
			// Seeds: B2/S (no survival)
			if (self_val > 0.5) {
				new_val = 0.0;
			} else {
				new_val = (n >= 1.5 && n <= 2.5) ? 1.0 : 0.0;
			}
		} else {
			// Day & Night: B3678/S34678
			if (self_val > 0.5) {
				new_val = (n >= 3.0 && n <= 4.5) || (n >= 6.0) ? 1.0 : 0.0;
			} else {
				new_val = (n >= 2.5 && n <= 3.5) || (n >= 5.5) ? 1.0 : 0.0;
			}
		}

		COLOR = vec4(vec3(new_val), 1.0);
	}
}
