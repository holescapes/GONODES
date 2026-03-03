shader_type canvas_item;
// Chromatic Aberration — RGB channel offset
// Inspired by various Shadertoy chromatic aberration effects

uniform sampler2D gn_tex0 : hint_default_white;
uniform vec2 gn_resolution;
uniform float intensity = 3.0;  // Pixel offset amount
uniform float radial_weight = 1.0;  // 0 = uniform offset, 1 = radial (stronger near edges)

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5);
	vec2 dir = uv - center;
	float dist = length(dir);

	// Scale offset by distance from center when radial_weight > 0
	float weight = mix(1.0, dist * 2.0, radial_weight);
	vec2 offset = (dir / max(dist, 0.001)) * intensity / gn_resolution * weight;

	float r = texture(gn_tex0, uv + offset).r;
	float g = texture(gn_tex0, uv).g;
	float b = texture(gn_tex0, uv - offset).b;
	float a = texture(gn_tex0, uv).a;

	COLOR = vec4(r, g, b, a);
}
