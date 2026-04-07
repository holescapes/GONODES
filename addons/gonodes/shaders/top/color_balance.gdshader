shader_type canvas_item;
// Color Balance — Lift / Gamma / Gain (shadows, midtones, highlights).

uniform sampler2D source_tex : hint_default_white;
uniform vec4 lift : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 gamma : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 gain : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 src = texture(source_tex, UV);
	// Lift (shadows): add offset to dark values
	vec3 c = src.rgb * gain.rgb + (lift.rgb - vec3(1.0));
	// Gamma (midtones): power curve
	vec3 g = max(gamma.rgb, vec3(0.001));
	c = pow(max(c, vec3(0.0)), 1.0 / g);
	COLOR = vec4(clamp(c, vec3(0.0), vec3(1.0)), src.a);
}
