shader_type canvas_item;
// Axis mirror shader for MirrorTOP.
// Places a mirror line at an arbitrary position and angle.

uniform sampler2D source_tex : hint_default_white;
uniform vec2 mirror_center = vec2(0.5, 0.5);
uniform float mirror_angle = 0.0; // radians, 0 = vertical axis
uniform int mirror_axis = 0; // 0 = vertical, 1 = horizontal, 2 = free angle

void fragment() {
	vec2 uv = UV;
	vec2 center = mirror_center;

	float angle;
	if (mirror_axis == 0) {
		angle = 0.0; // vertical line
	} else if (mirror_axis == 1) {
		angle = 1.5707963; // PI/2 = horizontal line
	} else {
		angle = mirror_angle;
	}

	// Normal of the mirror line (perpendicular direction)
	vec2 normal = vec2(cos(angle), sin(angle));

	// Signed distance from the mirror line through center
	vec2 delta = uv - center;
	float d = dot(delta, normal);

	// Reflect UVs that are on the negative side
	if (d < 0.0) {
		uv = uv - 2.0 * d * normal;
	}

	COLOR = texture(source_tex, clamp(uv, vec2(0.0), vec2(1.0)));
}
