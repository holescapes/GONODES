class_name GridFIX
extends GNFixtureBase
## 2D LED grid fixture.
## Places LEDs in a rectangular grid within a UV bounding box.
## Raster order: left-to-right, then top-to-bottom (row-major).


func _init() -> void:
	super._init()
	node_type = "grid_fix"
	node_description = "2D LED grid. Cols × rows of LEDs within a UV bounding box."


func _init_ports() -> void:
	add_output("out", GNFixtureBase.FIX_FAMILY, "Fixture layout")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("fixture_name", "grid",
		"Name", "Fixture label used in CHOP channel names and the viewer overlay."))
	add_parameter(GNParameter.create_int("cols", 16, 1, 512,
		"Columns", "Number of LEDs across (horizontal)."))
	add_parameter(GNParameter.create_int("rows", 16, 1, 512,
		"Rows", "Number of LEDs down (vertical)."))
	add_parameter(GNParameter.create_vector2("uv_min", Vector2(0.1, 0.1),
		"UV Min", "Top-left UV corner of the grid bounding box."))
	add_parameter(GNParameter.create_vector2("uv_max", Vector2(0.9, 0.9),
		"UV Max", "Bottom-right UV corner of the grid bounding box."))
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
	var cols: int = get_param_value("cols")
	var rows: int = get_param_value("rows")
	out.led_count = cols * rows
	out.channel_layout = ["rgb", "rgbw", "r", "g", "b", "w"][get_param_value("channel_layout")]
	out.channels_per_led = GNFixtureData.channels_for_layout(out.channel_layout)
	out.dmx_start = get_param_value("dmx_start")
	out.sample_extent = get_param_value("sample_extent")

	var uv_min: Vector2 = get_param_value("uv_min")
	var uv_max: Vector2 = get_param_value("uv_max")
	out.led_positions.resize(out.led_count)

	for row in range(rows):
		var v: float = uv_min.y if rows == 1 else lerpf(uv_min.y, uv_max.y, float(row) / float(rows - 1))
		for col in range(cols):
			var u: float = uv_min.x if cols == 1 else lerpf(uv_min.x, uv_max.x, float(col) / float(cols - 1))
			out.led_positions[row * cols + col] = Vector2(u, v)

	return out
