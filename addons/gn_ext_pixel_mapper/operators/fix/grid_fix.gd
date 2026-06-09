class_name GridFIX
extends GNFixtureBase
## 2D LED grid fixture.
## Outputs LEDs in a rectangular grid within a local unit square (0-1).
## Raster order: left-to-right, then top-to-bottom (row-major).
## Placement on the source image is handled by FixtureSamplerTOP.


func _init() -> void:
	super._init()
	node_type = "grid_fix"
	node_description = "2D LED grid. Cols x rows in a unit square. Place on source image via FixtureSamplerTOP."


func _init_ports() -> void:
	add_output("out", GNFixtureBase.FIX_FAMILY, "Fixture layout")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("fixture_name", "grid",
		"Name", "Fixture label used in CHOP channel names and the viewer overlay."))
	add_parameter(GNParameter.create_int("cols", 16, 1, 512,
		"Columns", "Number of LEDs across (horizontal)."))
	add_parameter(GNParameter.create_int("rows", 16, 1, 512,
		"Rows", "Number of LEDs down (vertical)."))
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
	var cols: int = get_param_value("cols")
	var rows: int = get_param_value("rows")
	out.led_count = cols * rows
	out.channel_layout = ["rgb", "rgbw", "r", "g", "b", "w"][get_param_value("channel_layout")]
	out.channels_per_led = GNFixtureData.channels_for_layout(out.channel_layout)
	out.universe = get_param_value("universe")
	out.start_channel = get_param_value("start_channel")
	out.shape = &"grid"

	# Local space: fill unit square (0,0) to (1,1), row-major
	out.led_positions.resize(out.led_count)
	for row in range(rows):
		var v: float = 0.0 if rows == 1 else float(row) / float(rows - 1)
		for col in range(cols):
			var u: float = 0.0 if cols == 1 else float(col) / float(cols - 1)
			out.led_positions[row * cols + col] = Vector2(u, v)

	return out
