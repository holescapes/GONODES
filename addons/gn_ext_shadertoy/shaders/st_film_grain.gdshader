shader_type canvas_item;
// Film Grain — adds animated noise grain over the image
// Inspired by various Shadertoy film grain shaders

uniform sampler2D gn_tex0 : hint_default_white;
uniform vec2 gn_resolution;
uniform float grain_intensity = 0.12;  // 0 = no grain, 1 = full noise
uniform float grain_speed = 1.0;       // Animation speed multiplier

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 col = texture(gn_tex0, UV);

	// Animated grain — different each frame
	float noise = rand(FRAGCOORD.xy + vec2(TIME * grain_speed * 100.0));
	noise = (noise - 0.5) * 2.0 * grain_intensity;

	// Apply grain — affects luminance only (preserves color)
	col.rgb += noise;

	COLOR = col;
}
