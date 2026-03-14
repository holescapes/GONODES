shader_type canvas_item;
// MonoTOP — grayscale conversion with multiple luma weight methods.

uniform sampler2D source_tex : hint_default_white;
uniform int method : hint_range(0, 3) = 0; // 0=Rec.709, 1=Rec.601, 2=Average, 3=Desaturate
uniform float mix_amount = 1.0;

void fragment() {
	vec4 col = texture(source_tex, UV);
	float gray;

	if (method == 0) {
		// Rec.709 (HDTV)
		gray = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
	} else if (method == 1) {
		// Rec.601 (SDTV)
		gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	} else if (method == 2) {
		// Simple average
		gray = (col.r + col.g + col.b) / 3.0;
	} else {
		// Desaturate (min+max)/2
		gray = (max(col.r, max(col.g, col.b)) + min(col.r, min(col.g, col.b))) * 0.5;
	}

	vec3 result = mix(col.rgb, vec3(gray), mix_amount);
	COLOR = vec4(result, col.a);
}
