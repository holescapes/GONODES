shader_type canvas_item;
// Film grain — adds temporal noise grain over the image.

uniform sampler2D source_tex : hint_default_white;
uniform float intensity : hint_range(0.0, 1.0) = 0.15;
uniform float size : hint_range(0.5, 4.0) = 1.0;
uniform float time_val : hint_range(0.0, 100000.0) = 0.0;
uniform bool luminance_dependent = true;

// Hash function for pseudo-random grain
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec4 src = texture(source_tex, UV);
	vec2 grain_uv = floor(UV * vec2(textureSize(source_tex, 0)) / size);
	float noise = hash(grain_uv + vec2(time_val * 7.13, time_val * 3.71)) * 2.0 - 1.0;

	float grain = noise * intensity;

	if (luminance_dependent) {
		// Less grain in highlights, more in midtones
		float luma = dot(src.rgb, vec3(0.2126, 0.7152, 0.0722));
		float mask = 1.0 - abs(luma * 2.0 - 1.0); // peak at midtones
		grain *= mask;
	}

	COLOR = vec4(src.rgb + vec3(grain), src.a);
}
