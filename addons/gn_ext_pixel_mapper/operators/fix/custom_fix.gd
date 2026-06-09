class_name CustomFIX
extends GNFixtureBase
## Custom LED positions loaded from a DAT input.
## Each row of the DAT provides one LED's UV coordinates.
## Required columns: "uv_x", "uv_y". Detected by header name.


func _init() -> void:
	super._init()
	node_type = "custom_fix"
	node_description = "Custom LED positions from a DAT. Each row = one LED. Required columns: uv_x, uv_y."


func _init_ports() -> void:
	add_input("dat", GNFamily.Type.DAT, false, "DAT with uv_x/uv_y columns")
	add_output("out", GNFixtureBase.FIX_FAMILY, "Fixture layout")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("fixture_name", "custom",
		"Name", "Fixture label used in CHOP channel names and the viewer overlay."))
	add_parameter(GNParameter.create_enum("channel_layout",
		PackedStringArray(["RGB", "RGBW", "R", "G", "B", "W"]), 0,
		"Channel Layout", "Colour channel order per LED."))
	add_parameter(GNParameter.create_int("dmx_start", 1, 0, 32767,
		"DMX Start", "First DMX channel (universe×512 + channel). 0 = unassigned."))
	add_parameter(GNParameter.create_vector2("sample_extent", Vector2.ZERO,
		"Sample Extent", "UV half-size of the box-filter area per LED. (0,0) = point sample."))


func _cook(inputs: Array[GNData]) -> GNData:
	var dat_data: GNTableData = inputs[0] as GNTableData if inputs.size() > 0 and inputs[0] is GNTableData else null
	if dat_data == null or dat_data.num_rows() == 0:
		node_warning = "No DAT input connected."
		return null

	# Find uv_x / uv_y column indices from the header row
	var hdrs: PackedStringArray = dat_data.get_headers()
	var x_col: int = hdrs.find("uv_x")
	var y_col: int = hdrs.find("uv_y")
	if x_col < 0 or y_col < 0:
		node_warning = "DAT must have 'uv_x' and 'uv_y' columns."
		return null

	node_warning = ""
	var out: GNFixtureData = _prepare_output()
	out.fixture_name = get_param_value("fixture_name")
	out.channel_layout = ["rgb", "rgbw", "r", "g", "b", "w"][get_param_value("channel_layout")]
	out.channels_per_led = GNFixtureData.channels_for_layout(out.channel_layout)
	out.dmx_start = get_param_value("dmx_start")
	out.sample_extent = get_param_value("sample_extent")
	out.led_count = dat_data.num_rows()
	out.led_positions.resize(out.led_count)

	for i in range(dat_data.num_rows()):
		var ux: float = float(dat_data.cell(i, x_col))
		var uy: float = float(dat_data.cell(i, y_col))
		out.led_positions[i] = Vector2(ux, uy)

	return out
