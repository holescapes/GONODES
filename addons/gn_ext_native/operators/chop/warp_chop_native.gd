class_name WarpCHOPNative
extends GNChopBase
## Native-accelerated time warp — delegates to GNNativeWarpChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "warp"
	node_description = "Time-warp / retime channel data — native C++ accelerated."
	if ClassDB.class_exists("GNNativeWarpChop"):
		_processor = ClassDB.instantiate("GNNativeWarpChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels to retime")
	add_input("warp", GNFamily.Type.CHOP, false, "Warp curve (optional)")
	add_output("out", GNFamily.Type.CHOP, "Warped channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("speed", 1.0, -10.0, 10.0, 0.01, "Speed", "Time speed multiplier"))
	add_parameter(GNParameter.create_float("offset", 0.0, -1000.0, 1000.0, 0.01, "Offset", "Sample offset"))
	add_parameter(GNParameter.create_int("output_length", 0, 0, 100000, "Output Length", "0 = match input"))
	add_parameter(GNParameter.create_enum("interpolation",
		PackedStringArray(["Linear", "Nearest"]), 0, "", "Interpolation mode"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var warp_data: GNChannelData = _get_input_chop(inputs, 1)
	var quality: int = get_param_value("interpolation")

	# Build warp curve from second input or from speed/offset params
	var warp_curve := PackedFloat32Array()
	if warp_data != null:
		for ch_name in warp_data.channels:
			warp_curve = warp_data.channels[ch_name]
			break

	if _processor != null:
		var channels := {}
		for ch_name in in_data.channels:
			channels[ch_name] = in_data.channels[ch_name]
		var result: Dictionary = _processor.process(channels, warp_curve, quality)
		var out: GNChannelData = _prepare_output(in_data.sample_rate)
		for key in result:
			out.channels[key] = result[key]
		out.length = in_data.length
		return out
	else:
		return null
