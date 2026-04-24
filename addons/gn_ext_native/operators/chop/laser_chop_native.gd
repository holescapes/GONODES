class_name LaserCHOPNative
extends GNChopBase
## Native-accelerated laser pattern generator — delegates to GNNativeLaserChop (C++).

var _processor: RefCounted = null
var _angle_accum: float = 0.0


func _init() -> void:
	node_type = "laser_native"
	time_dependent = true
	node_description = "Generate ILDA laser control channels — native C++ accelerated."
	if ClassDB.class_exists("GNNativeLaserChop"):
		_processor = ClassDB.instantiate("GNNativeLaserChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Modulation input (optional)")
	add_output("out", GNFamily.Type.CHOP, "Laser XY + RGB + intensity channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("pattern",
		PackedStringArray(["Circle", "Line", "Square", "Spiral", "ILDA Test"]), 0,
		"Pattern", "Laser test pattern"))
	add_parameter(GNParameter.create_int("points", 200, 10, 10000,
		"Points", "Number of output points"))
	add_parameter(GNParameter.create_float("scale", 1.0, 0.01, 2.0, 0.01,
		"Scale", "Pattern scale"))
	add_parameter(GNParameter.create_float("rotation", 0.0, -360.0, 360.0, 0.1,
		"Rotation", "Static rotation (degrees)"))
	add_parameter(GNParameter.create_bool("animate", false, "Animate",
		"Enable continuous rotation"))
	add_parameter(GNParameter.create_float("speed", 30.0, 0.1, 360.0, 0.1,
		"Speed", "Rotation speed (degrees/sec)"))
	add_parameter(GNParameter.create_color("color", Color.GREEN, "Color",
		"Beam color"))
	add_parameter(GNParameter.create_float("intensity", 1.0, 0.0, 1.0, 0.01,
		"Intensity", "Blanking intensity"))
	add_parameter(GNParameter.create_int("blank_points", 5, 0, 50,
		"Blank Points", "Blanking dwell points between segments"))


func _cook(inputs: Array[GNData]) -> GNData:
	if not _processor:
		return null

	if get_param_value("animate"):
		_angle_accum += get_param_value("speed") * current_delta
	else:
		_angle_accum = get_param_value("rotation")

	var col: Color = get_param_value("color")

	var result: Dictionary = _processor.process(
		get_param_value("pattern"), get_param_value("points"),
		get_param_value("scale"), _angle_accum,
		col.r, col.g, col.b, get_param_value("intensity"),
		get_param_value("blank_points"), _angle_accum)

	var out: GNChannelData = _prepare_output(60.0)
	for ch_name in result:
		out.channels[ch_name] = result[ch_name]
	if result.has("x"):
		out.length = result["x"].size()
	return out
