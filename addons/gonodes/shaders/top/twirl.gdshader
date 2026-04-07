shader_type canvas_item;
// Twirl / swirl distortion.

uniform sampler2D source_tex : hint_default_white;
uniform float strength : hint_range(-10.0, 10.0) = 3.0;
uniform float radius : hint_range(0.01, 2.0) = 0.5;
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	vec2 uv = UV - center;
	float dist = length(uv);
	float falloff = max(1.0 - dist / radius, 0.0);
	float angle_val = strength * falloff * falloff;
	float cs = cos(angle_val);
	float sn = sin(angle_val);
	vec2 rotated = vec2(uv.x * cs - uv.y * sn, uv.x * sn + uv.y * cs);
	vec2 new_uv = rotated + center;
	new_uv = clamp(new_uv, vec2(0.0), vec2(1.0));
	COLOR = texture(source_tex, new_uv);
}
