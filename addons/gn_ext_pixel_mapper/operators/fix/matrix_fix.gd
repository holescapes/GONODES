class_name MatrixFIX
extends GNFixtureBase
## LED matrix fixture with pixel pitch, rotation, and skew.
## Designed for stage LED walls and irregular panels where GridFIX
## is too simple. Supports non-square pitch and panel-level rotation.


func _init() -> void:
	super._init()
	node_type = "matrix_fix"
	node_description = "LED matrix with configurable pitch, rotation, and skew for stage walls and irregular panels."


func _init_ports() -> void:
	add_output("out", GNFixtureBase.FIX_FAMILY, "Fixture layout")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("fixture_name", "matrix",
		"Name", "Fixture label used in CHOP channel names and the viewer overlay."))
	add_parameter(GNParameter.create_int("cols", 16, 1, 512,
		"Columns", "Number of LEDs across."))
	add_parameter(GNParameter.create_int("rows", 16, 1, 512,
		"Rows", "Number of LEDs down."))
	add_parameter(GNParameter.create_vector2("uv_origin", Vector2(0.1, 0.1),
		"UV Origin", "UV position of the top-left LED."))
	add_parameter(GNParameter.create_vector2("uv_pitch", Vector2(0.05, 0.05),
		"UV Pitch", "UV step between adjacent LEDs (horizontal, vertical)."))
	add_parameter(GNParameter.create_float("rotation_deg", 0.0, -180.0, 180.0, 0.1,
		"Rotation", "Panel rotation in degrees around its UV origin."))
	add_parameter(GNParameter.create_float("skew_x", 0.0, -1.0, 1.0, 0.001,
		"Skew X", "Horizontal shear — shifts each row right by this UV amount."))
	add_parameter(GNParameter.create_float("skew_y", 0.0, -1.0, 1.0, 0.001,
		"Skew Y", "Vertical shear — shifts each column down by this UV amount."))
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

	var origin: Vector2   = get_param_value("uv_origin")
	var pitch: Vector2    = get_param_value("uv_pitch")
	var rot_deg: float    = get_param_value("rotation_deg")
	var skew_x: float     = get_param_value("skew_x")
	var skew_y: float     = get_param_value("skew_y")
	var rot_rad: float    = deg_to_rad(rot_deg)
	var cos_r: float      = cos(rot_rad)
	var sin_r: float      = sin(rot_rad)

	out.led_positions.resize(out.led_count)

	for row in range(rows):
		for col in range(cols):
			# Local position in LED-grid space (before rotation)
			var lx: float = col * pitch.x + row * skew_x
			var ly: float = row * pitch.y + col * skew_y
			# Rotate around origin
			var rx: float = lx * cos_r - ly * sin_r
			var ry: float = lx * sin_r + ly * cos_r
			out.led_positions[row * cols + col] = origin + Vector2(rx, ry)

	return out
