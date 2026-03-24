class_name LogicCHOP
extends GNChopBase
## Performs boolean/logic operations on CHOP channels.
## Converts input to boolean (>= threshold → true), then applies logic.
## Similar to TouchDesigner's Logic CHOP.

enum LogicOp { AND, OR, XOR, NAND, NOR, NOT }


func _init() -> void:
	node_type = "logic"


func _init_ports() -> void:
	add_input("in1", GNFamily.Type.CHOP, false, "First input", "Input 1")
	add_input("in2", GNFamily.Type.CHOP, false, "Second input", "Input 2")
	add_output("out", GNFamily.Type.CHOP, "Logic result (0 or 1)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("operation",
		PackedStringArray(["AND", "OR", "XOR", "NAND", "NOR", "NOT"]), 0, "", "Logic operation to apply"))
	add_parameter(GNParameter.create_float("threshold", 0.5, null, null, 0.01, "", "Boolean threshold (>= = true)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in1: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	var in2: GNChannelData = inputs[1] as GNChannelData if inputs.size() > 1 and inputs[1] is GNChannelData else null

	if in1 == null:
		GNLogger.warn("LogicCHOP", "'%s' — no valid input" % id)
		return null

	var op_idx: int = get_param_value("operation")
	var thresh: float = get_param_value("threshold")

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = in1.sample_rate

	for ch_name in in1.channels:
		var samples_a: PackedFloat32Array = in1.channels[ch_name]
		var out_samples := PackedFloat32Array()
		out_samples.resize(samples_a.size())

		var has_b: bool = in2 != null and in2.channels.has(ch_name)
		var samples_b: PackedFloat32Array = in2.channels[ch_name] if has_b else PackedFloat32Array()

		for i in range(samples_a.size()):
			var a_bool: bool = samples_a[i] >= thresh
			var b_bool: bool = (samples_b[i] >= thresh) if (has_b and i < samples_b.size()) else false

			var result: bool = false
			match op_idx:
				LogicOp.AND:
					result = a_bool and b_bool
				LogicOp.OR:
					result = a_bool or b_bool
				LogicOp.XOR:
					result = a_bool != b_bool
				LogicOp.NAND:
					result = not (a_bool and b_bool)
				LogicOp.NOR:
					result = not (a_bool or b_bool)
				LogicOp.NOT:
					result = not a_bool

			out_samples[i] = 1.0 if result else 0.0

		_cached_channel_data.set_channel(ch_name, out_samples)

	return _cached_channel_data
