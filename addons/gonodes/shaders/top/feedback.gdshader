shader_type canvas_item;
// Feedback shader for FeedbackTOP.
// Blends the current input with the previous frame's output.

uniform sampler2D source_tex : hint_default_white;
uniform sampler2D feedback_tex : hint_default_black;
uniform float feedback_mix : hint_range(0.0, 1.0) = 0.9;
uniform vec2 fb_translate = vec2(0.0, 0.0);
uniform float fb_rotate = 0.0; // radians
uniform vec2 fb_scale = vec2(1.0, 1.0);

void fragment() {
	vec2 fb_uv = UV - 0.5;
	fb_uv /= max(fb_scale, vec2(0.001));
	float c = cos(fb_rotate);
	float s = sin(fb_rotate);
	fb_uv = vec2(fb_uv.x * c - fb_uv.y * s, fb_uv.x * s + fb_uv.y * c);
	fb_uv -= fb_translate;
	fb_uv += 0.5;

	vec4 current = texture(source_tex, UV);
	vec4 prev = texture(feedback_tex, clamp(fb_uv, vec2(0.0), vec2(1.0)));
	COLOR = mix(current, prev, feedback_mix);
}
