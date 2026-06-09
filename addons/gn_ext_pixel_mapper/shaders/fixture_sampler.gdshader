shader_type canvas_item;
// FixtureSamplerTOP — samples a source image at every LED UV position.
//
// Inputs:
//   source_tex       — the image to sample from
//   led_pos_tex      — packed LED-position texture:
//                        each pixel is (uv_x, uv_y, extent_x, extent_y)
//                        width = total_leds, height = 1
//   total_leds       — total LED count across all fixtures (width of led_pos_tex)
//   sample_mode      — 0 = point, 1 = box-filter (uses extent from led_pos_tex)
//
// Output texture layout:
//   width  = max_channels_per_led (1–4)
//   height = total_leds
//   pixel (channel, led) = that channel's value for that LED  (R component)
//   This keeps the result compact and avoids any fixed-width assumptions.

uniform sampler2D source_tex : filter_linear, repeat_disable;
uniform sampler2D led_pos_tex : filter_nearest, repeat_disable;
uniform int total_leds = 0;
uniform int sample_mode = 0;          // 0=point, 1=box
uniform int channels_per_led = 3;     // 1–4

void fragment() {
	// UV maps to: x = channel index (0..channels_per_led-1), y = led index (0..total_leds-1)
	int channel_idx = int(UV.x * float(channels_per_led));
	int led_idx     = int(UV.y * float(total_leds));

	if (led_idx >= total_leds || channel_idx >= channels_per_led) {
		COLOR = vec4(0.0);
	} else {
		// Read LED position from packed texture (normalised index)
		float led_u = (float(led_idx) + 0.5) / float(total_leds);
		vec4 pos_data = texture(led_pos_tex, vec2(led_u, 0.5));
		vec2 led_uv   = pos_data.rg;   // uv_x, uv_y
		vec2 extent   = pos_data.ba;   // half-extents for box filter

		vec4 sampled;
		if (sample_mode == 1 && (extent.x > 0.0 || extent.y > 0.0)) {
			// 3x3 tap box filter -- cheap but effective for small extents
			vec4 acc = vec4(0.0);
			for (int dy = -1; dy <= 1; dy++) {
				for (int dx = -1; dx <= 1; dx++) {
					vec2 tap = led_uv + vec2(float(dx) * extent.x, float(dy) * extent.y);
					acc += texture(source_tex, tap);
				}
			}
			sampled = acc / 9.0;
		} else {
			sampled = texture(source_tex, led_uv);
		}

		// Route the requested channel into the red output component
		float value = 0.0;
		if (channel_idx == 0)      value = sampled.r;
		else if (channel_idx == 1) value = sampled.g;
		else if (channel_idx == 2) value = sampled.b;
		else if (channel_idx == 3) value = sampled.a;

		COLOR = vec4(value, value, value, 1.0);
	}
}
