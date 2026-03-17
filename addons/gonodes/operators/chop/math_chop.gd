class_name MathCHOP
extends GNChopBase
## Performs per-sample math operations on CHOP channel data.
## With 1 input: applies unary operation (Abs, Sin, Cos) or uses operand parameter.
## With 2 inputs: applies binary operation channel-by-channel.
## Channel matching priority when **channel_name** is empty:
##   (1) same name, (2) single-channel broadcast, (3) index-based positional match.
## When **channel_name** is set, that specific in2 channel is used for every in1 channel.

enum Operation { ADD, SUBTRACT, MULTIPLY, DIVIDE, ABS, SIN, COS, POW }


func _init() -> void:
	node_type = "math"
	node_description = "Per-sample math on CHOP channels."


func _init_ports() -> void:
	add_input("in1", GNFamily.Type.CHOP, false, "First input (required)", "Input 1")
	add_input("in2", GNFamily.Type.CHOP, false, "Second input (optional, uses operand if absent)", "Input 2")
	add_output("out", GNFamily.Type.CHOP, "Math result")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("operation",
		PackedStringArray(["Add", "Subtract", "Multiply", "Divide",
			"Abs", "Sin", "Cos", "Pow"]), 0, "", "Math operation to apply"))
	add_parameter(GNParameter.create_float("operand", 0.0, null, null, 0.01, "", "Scalar operand when in2 is absent"))
	add_parameter(GNParameter.create_string("channel_name", "", "",
		"Pick a specific channel from in2 (empty = auto-match)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var op_idx: int = get_param_value("operation")
	var operand_val: float = get_param_value("operand")
	var chan_select: String = get_param_value("channel_name").strip_edges()

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

	# Pre-compute the in2 channel to use.
	# If channel_name is set, lock to that specific channel (broadcast to all in1 channels).
	# Otherwise fall back to auto-matching: name → single-channel → index.
	var in2_selected_samples: PackedFloat32Array = PackedFloat32Array()
	var in2_single_samples: PackedFloat32Array = PackedFloat32Array()
	var in2_keys_ordered: Array[String] = []
	if in2 != null:
		if not chan_select.is_empty() and in2.channels.has(chan_select):
			in2_selected_samples = in2.channels[chan_select]
		else:
			if not chan_select.is_empty():
				GNLogger.warn("MathCHOP",
					"'%s' — channel_name '%s' not found in in2, using auto-match" % [id, chan_select])
			in2_keys_ordered.assign(in2.channels.keys())
			if in2_keys_ordered.size() == 1:
				in2_single_samples = in2.channels[in2_keys_ordered[0]]

	var ch_idx: int = 0
	for ch_name in in1.channels:
		var samples_a: PackedFloat32Array = in1.channels[ch_name]
		var out_samples := PackedFloat32Array()
		out_samples.resize(samples_a.size())

		if in2 != null:
			var samples_b: PackedFloat32Array = PackedFloat32Array()

			# 0) Explicit channel_name selection (broadcast)
			if in2_selected_samples.size() > 0:
				samples_b = in2_selected_samples
			# 1) Matching channel name
			elif in2.channels.has(ch_name):
				samples_b = in2.channels[ch_name]
			# 2) Single-channel broadcast
			elif in2_single_samples.size() > 0:
				samples_b = in2_single_samples
			# 3) Index match
			elif ch_idx < in2_keys_ordered.size():
				samples_b = in2.channels[in2_keys_ordered[ch_idx]]

			if samples_b.size() > 0:
				for i in range(samples_a.size()):
					var b_val: float = samples_b[i] if i < samples_b.size() else samples_b[samples_b.size() - 1]
					out_samples[i] = _apply_binary(op_idx, samples_a[i], b_val)
			else:
				# in2 connected but no usable channel — fall back to operand param
				for i in range(samples_a.size()):
					out_samples[i] = _apply_unary(op_idx, samples_a[i], operand_val)
		else:
			# No second input — unary operation or binary with operand parameter
			for i in range(samples_a.size()):
				out_samples[i] = _apply_unary(op_idx, samples_a[i], operand_val)

		_cached_channel_data.set_channel(ch_name, out_samples)
		ch_idx += 1

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
