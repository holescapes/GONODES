shader_type canvas_item;
// NormalMapTOP — generate a normal map from a height/displacement map.

uniform sampler2D source_tex : hint_default_white;
uniform float strength = 1.0;
uniform bool invert_y = false;

void fragment() {
	vec2 texel = vec2(1.0) / vec2(textureSize(source_tex, 0));

	float left  = dot(texture(source_tex, UV + vec2(-texel.x, 0.0)).rgb, vec3(0.2126, 0.7152, 0.0722));
	float right = dot(texture(source_tex, UV + vec2( texel.x, 0.0)).rgb, vec3(0.2126, 0.7152, 0.0722));
	float up    = dot(texture(source_tex, UV + vec2(0.0, -texel.y)).rgb, vec3(0.2126, 0.7152, 0.0722));
	float down  = dot(texture(source_tex, UV + vec2(0.0,  texel.y)).rgb, vec3(0.2126, 0.7152, 0.0722));

	float dx = (right - left) * strength;
	float dy = (down - up) * strength;

	if (invert_y) {
		dy = -dy;
	}

	// Normal in tangent space, encoded as 0..1 for storage
	vec3 normal = normalize(vec3(dx, dy, 1.0));
	COLOR = vec4(normal * 0.5 + 0.5, 1.0);
}
