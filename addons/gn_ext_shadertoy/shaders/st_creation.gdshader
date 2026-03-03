shader_type canvas_item;
// Auto-translated from Shadertoy — "Creation" by Danguafer/Silexars
// 2nd place @ DemoJS 2011 — first 1k WebGL intro ever released
// https://www.shadertoy.com/view/XsXXDn
// Credits: Danilo Guanabara

uniform vec2 gn_resolution;

void fragment() {
	vec3 c;
	float l, z = TIME;
	for (int i = 0; i < 3; i++) {
		vec2 uv, p = FRAGCOORD.xy / gn_resolution;
		uv = p;
		p -= 0.5;
		p.x *= gn_resolution.x / gn_resolution.y;
		z += 0.07;
		l = length(p);
		uv += p / l * (sin(z) + 1.0) * abs(sin(l * 9.0 - z - z));
		c[i] = 0.01 / length(mod(uv, 1.0) - 0.5);
	}
	COLOR = vec4(c / l, TIME);
}
