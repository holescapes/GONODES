class_name StripFIX
extends GNFixtureBase
## Linear LED strip fixture.
## Places N LEDs evenly spaced along a line between two UV endpoints.


func _init() -> void:
	super._init()
	node_type = "strip_fix"
	node_description = "Linear LED strip. N LEDs evenly spaced between two UV points."


func _init_ports() -> void:
	add_output("out", GNFixtureBase.FIX_FAMILY, "Fixture layout")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("fixture_name", "strip",
		"Name", "Fixture label used in CHOP channel names and the viewer overlay."))
	add_parameter(GNParameter.create_int("led_count", 60, 1, 2048,
		"LED Count", "Total number of LEDs in the strip."))
	add_parameter(GNParameter.create_vector2("uv_start", Vector2(0.1, 0.5),
		"UV Start", "UV coordinate of the first LED (0–1 on both axes)."))
	add_parameter(GNParameter.create_vector2("uv_end", Vector2(0.9, 0.5),
		"UV End", "UV coordinate of the last LED (0–1 on both axes)."))
	add_parameter(GNParameter.create_enum("channel_layout",
		PackedStringArray(["RGB", "RGBW", "R", "G", "B", "W"]), 0,
		"Channel Layout", "Colour channel order per LED."))
	add_parameter(GNParameter.create_int("dmx_start", 1, 0, 32767,
		"DMX Start", "First DMX channel (universe×512 + channel). 0 = unassigned."))
	add_parameter(GNParameter.create_vector2("sample_extent", Vector2.ZERO,
		"Sample Extent", "UV half-size of the box-filter area per LED. (0,0) = point sample."))


func _cook(_inputs: Array[GNData]) -> GNData:
	var out: GNFixtureData = _prepare_output()
	out.fixture_name = get_param_value("fixture_name")
	out.led_count = get_param_value("led_count")
	out.channel_layout = ["rgb", "rgbw", "r", "g", "b", "w"][get_param_value("channel_layout")]
	out.channels_per_led = GNFixtureData.channels_for_layout(out.channel_layout)
	out.dmx_start = get_param_value("dmx_start")
	out.sample_extent = get_param_value("sample_extent")

	var uv_start: Vector2 = get_param_value("uv_start")
	var uv_end: Vector2 = get_param_value("uv_end")
	out.led_positions.resize(out.led_count)

	if out.led_count == 1:
		out.led_positions[0] = (uv_start + uv_end) * 0.5
	else:
		for i in range(out.led_count):
			var t: float = float(i) / float(out.led_count - 1)
			out.led_positions[i] = uv_start.lerp(uv_end, t)

	return out
