class_name StripFIX
extends GNFixtureBase
## Linear LED strip fixture.
## Outputs N LEDs evenly spaced in local space (0-1 along x, y=0.5).
## Placement on the source image is handled by FixtureSamplerTOP.


func _init() -> void:
	super._init()
	node_type = "strip_fix"
	node_description = "Linear LED strip. N LEDs in a line. Place on source image via FixtureSamplerTOP."


func _init_ports() -> void:
	add_output("out", GNFixtureBase.FIX_FAMILY, "Fixture layout")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("fixture_name", "strip",
		"Name", "Fixture label used in CHOP channel names and the viewer overlay."))
	add_parameter(GNParameter.create_int("led_count", 60, 1, 2048,
		"LED Count", "Total number of LEDs in the strip."))
	add_parameter(GNParameter.create_enum("channel_layout",
		PackedStringArray(["RGB", "RGBW", "R", "G", "B", "W"]), 0,
		"Channel Layout", "Colour channel order per LED."))
	add_parameter(GNParameter.create_int("universe", 1, 1, 32767,
		"Universe", "DMX universe (1-based)."))
	add_parameter(GNParameter.create_int("start_channel", 1, 1, 512,
		"Start Channel", "First DMX channel within the universe (1-512)."))


func _cook(_inputs: Array[GNData]) -> GNData:
	var out: GNFixtureData = _prepare_output()
	out.fixture_name = get_param_value("fixture_name")
	out.led_count = get_param_value("led_count")
	out.channel_layout = ["rgb", "rgbw", "r", "g", "b", "w"][get_param_value("channel_layout")]
	out.channels_per_led = GNFixtureData.channels_for_layout(out.channel_layout)
	out.universe = get_param_value("universe")
	out.start_channel = get_param_value("start_channel")
	out.shape = &"strip"

	# Local space: LEDs along x from 0 to 1, y = 0.5
	out.led_positions.resize(out.led_count)
	if out.led_count == 1:
		out.led_positions[0] = Vector2(0.5, 0.5)
	else:
		for i in range(out.led_count):
			var t: float = float(i) / float(out.led_count - 1)
			out.led_positions[i] = Vector2(t, 0.5)

	return out
