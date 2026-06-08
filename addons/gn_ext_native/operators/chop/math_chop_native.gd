class_name MathCHOPNative
extends GNChopBase
## Native-accelerated per-sample math — delegates to GNNativeMathChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "math_native"
	node_description = "Per-sample math on CHOP channels — native C++ accelerated."
	if ClassDB.class_exists("GNNativeMathChop"):
		_processor = ClassDB.instantiate("GNNativeMathChop")


func _init_ports() -> void:
	add_input("in1", GNFamily.Type.CHOP, false, "First input (required)", "In1")
	add_input("in2", GNFamily.Type.CHOP, false, "Second input (optional)", "In2")
	add_output("out", GNFamily.Type.CHOP, "Math result", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("operation",
		PackedStringArray(["Add", "Subtract", "Multiply", "Divide",
			"Abs", "Sin", "Cos", "Pow"]), 0, "", "Math operation"))
	add_parameter(GNParameter.create_float("operand", 0.0, null, null, 0.01, "",
		"Scalar operand when in2 is absent"))
	add_parameter(GNParameter.create_string("channel_name", "", "",
		"Pick a specific channel from in2"))


func _cook(inputs: Array[GNData]) -> GNData:
	var op_idx: int = get_param_value("operation")
	var operand_val: float = get_param_value("operand")
	var in1: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	var in2: GNChannelData = inputs[1] as GNChannelData if inputs.size() > 1 and inputs[1] is GNChannelData else null

	if in1 == null:
		return null

	if _processor != null:
		var ch_a := {}
		for ch_name in in1.channels:
			ch_a[ch_name] = in1.channels[ch_name]

		var result: Dictionary
		if in2 != null:
			var ch_b := {}
			for ch_name in in2.channels:
				ch_b[ch_name] = in2.channels[ch_name]
			result = _processor.process_binary(ch_a, ch_b, op_idx)
		else:
			result = _processor.process_unary(ch_a, op_idx, operand_val)

		var out: GNChannelData = _prepare_output(in1.sample_rate)
		for key in result:
			out.channels[key] = result[key]
		out.length = in1.length
		return out
	else:
		return null
