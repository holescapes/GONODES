class_name MathCHOP
extends GNNode
## Performs per-sample math operations on CHOP channel data.
## With 1 input: applies unary operation (Abs, Sin, Cos) or uses operand parameter.
## With 2 inputs: applies binary operation channel-by-channel.

enum Operation { ADD, SUBTRACT, MULTIPLY, DIVIDE, ABS, SIN, COS, POW }

## Reusable output data object (created once, updated each cook).
var _cached_channel_data: GNChannelData = null


func _init() -> void:
	node_type = "math"
	family = GNFamily.Type.CHOP
	node_description = "Per-sample math on CHOP channels."


func _init_ports() -> void:
	add_input("in1", GNFamily.Type.CHOP, false, "First input (required)")
	add_input("in2", GNFamily.Type.CHOP, false, "Second input (optional, uses operand if absent)")
	add_output("out", GNFamily.Type.CHOP, "Math result")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("operation",
		PackedStringArray(["Add", "Subtract", "Multiply", "Divide",
			"Abs", "Sin", "Cos", "Pow"]), 0, "", "Math operation to apply"))
	add_parameter(GNParameter.create_float("operand", 0.0, null, null, 0.01, "", "Scalar operand when in2 is absent"))


func _cook(inputs: Array[GNData]) -> GNData:
	var op_idx: int = get_param_value("operation")
	var operand_val: float = get_param_value("operand")

	var in1: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	var in2: GNChannelData = inputs[1] as GNChannelData if inputs.size() > 1 and inputs[1] is GNChannelData else null

	if in1 == null:
		GNLogger.warn("MathCHOP", "'%s' — no valid input on port 0" % id)
		return null

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

		if in2 != null and in2.channels.has(ch_name):
			# Binary operation with matching channel from input 2
			var samples_b: PackedFloat32Array = in2.channels[ch_name]
			for i in range(samples_a.size()):
				var b_val: float = samples_b[i] if i < samples_b.size() else 0.0
				out_samples[i] = _apply_binary(op_idx, samples_a[i], b_val)
		else:
			# Unary operation or binary with operand parameter
			for i in range(samples_a.size()):
				out_samples[i] = _apply_unary(op_idx, samples_a[i], operand_val)

		_cached_channel_data.set_channel(ch_name, out_samples)

	return _cached_channel_data


## Applies a binary operation on two values.
func _apply_binary(op_idx: int, a: float, b: float) -> float:
	match op_idx:
		Operation.ADD:
			return a + b
		Operation.SUBTRACT:
			return a - b
		Operation.MULTIPLY:
			return a * b
		Operation.DIVIDE:
			return a / b if b != 0.0 else 0.0
		Operation.ABS:
			return absf(a)
		Operation.SIN:
			return sin(a)
		Operation.COS:
			return cos(a)
		Operation.POW:
			return pow(a, b) if a >= 0.0 else 0.0
		_:
			return a


## Applies a unary operation (or binary with the operand parameter).
func _apply_unary(op_idx: int, a: float, operand: float) -> float:
	match op_idx:
		Operation.ADD:
			return a + operand
		Operation.SUBTRACT:
			return a - operand
		Operation.MULTIPLY:
			return a * operand
		Operation.DIVIDE:
			return a / operand if operand != 0.0 else 0.0
		Operation.ABS:
			return absf(a)
		Operation.SIN:
			return sin(a)
		Operation.COS:
			return cos(a)
		Operation.POW:
			return pow(a, operand) if a >= 0.0 else 0.0
		_:
			return a
