class_name CustomFIX
extends GNFixtureBase
## Custom LED positions loaded from a DAT input.
## Each row of the DAT provides one LED's local coordinates.
## Required columns: "x", "y". Detected by header name.
## Placement on the source image is handled by FixtureSamplerTOP.


func _init() -> void:
	super._init()
	node_type = "custom_fix"
	node_description = "Custom LED positions from a DAT. Each row = one LED. Required columns: x, y."


func _init_ports() -> void:
	add_input("dat", GNFamily.Type.DAT, false, "DAT with x/y columns")
	add_output("out", GNFixtureBase.FIX_FAMILY, "Fixture layout")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("fixture_name", "custom",
		"Name", "Fixture label used in CHOP channel names and the viewer overlay."))
	add_parameter(GNParameter.create_enum("channel_layout",
		PackedStringArray(["RGB", "RGBW", "R", "G", "B", "W"]), 0,
		"Channel Layout", "Colour channel order per LED."))
	add_parameter(GNParameter.create_int("universe", 1, 1, 32767,
		"Universe", "DMX universe (1-based)."))
	add_parameter(GNParameter.create_int("start_channel", 1, 1, 512,
		"Start Channel", "First DMX channel within the universe (1-512)."))


func _cook(inputs: Array[GNData]) -> GNData:
	var dat_data: GNTableData = inputs[0] as GNTableData if inputs.size() > 0 and inputs[0] is GNTableData else null
	if dat_data == null or dat_data.num_rows() == 0:
		node_warning = "No DAT input connected."
		return null

	# Find x / y column indices from the header row
	var hdrs: PackedStringArray = dat_data.get_headers()
	var x_col: int = hdrs.find("x")
	var y_col: int = hdrs.find("y")
	if x_col < 0 or y_col < 0:
		node_warning = "DAT must have 'x' and 'y' columns."
		return null

	node_warning = ""
	var out: GNFixtureData = _prepare_output()
	out.fixture_name = get_param_value("fixture_name")
	out.channel_layout = ["rgb", "rgbw", "r", "g", "b", "w"][get_param_value("channel_layout")]
	out.channels_per_led = GNFixtureData.channels_for_layout(out.channel_layout)
	out.universe = get_param_value("universe")
	out.start_channel = get_param_value("start_channel")
	out.shape = &"custom"
	out.led_count = dat_data.num_rows()
	out.led_positions.resize(out.led_count)

	for i in range(dat_data.num_rows()):
		var px: float = float(dat_data.cell(i, x_col))
		var py: float = float(dat_data.cell(i, y_col))
		out.led_positions[i] = Vector2(px, py)

	return out
