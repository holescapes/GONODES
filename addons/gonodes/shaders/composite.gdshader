shader_type canvas_item;
// Composite shader for CompositeTOP.
// Blends two input textures (A and B) using a selected blend operation.

uniform sampler2D texture_a : hint_default_white;
uniform sampler2D texture_b : hint_default_black;
uniform int operation = 0; // 0=Add, 1=Multiply, 2=Over, 3=Screen, 4=Subtract, 5=Difference
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 a = texture(texture_a, UV);
	vec4 b = texture(texture_b, UV);
	vec4 result;

	switch (operation) {
		case 0: // Add
			result = vec4(a.rgb + b.rgb * opacity, max(a.a, b.a));
			break;
		case 1: // Multiply
			result = vec4(mix(a.rgb, a.rgb * b.rgb, opacity), max(a.a, b.a));
			break;
		case 2: // Over (standard alpha composite: B over A)
			float out_a = b.a * opacity + a.a * (1.0 - b.a * opacity);
			vec3 out_rgb = (b.rgb * b.a * opacity + a.rgb * a.a * (1.0 - b.a * opacity));
			result = vec4(out_a > 0.0 ? out_rgb / out_a : vec3(0.0), out_a);
			break;
		case 3: // Screen
			result = vec4(mix(a.rgb, 1.0 - (1.0 - a.rgb) * (1.0 - b.rgb), opacity), max(a.a, b.a));
			break;
		case 4: // Subtract
			result = vec4(a.rgb - b.rgb * opacity, max(a.a, b.a));
			break;
		case 5: // Difference
			result = vec4(mix(a.rgb, abs(a.rgb - b.rgb), opacity), max(a.a, b.a));
			break;
		default:
			result = a;
			break;
	}

	COLOR = clamp(result, vec4(0.0), vec4(1.0));
}
