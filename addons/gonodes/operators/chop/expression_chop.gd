class_name ExpressionCHOP
extends GNChopBase
## Evaluates user-written GDScript expressions per channel.
## Variables available: v (current value), i (sample index), n (sample count),
## t (elapsed_time), dt (delta), ch (channel name), me (this node).
## Uses Godot's Expression class for sandboxed evaluation.


func _init() -> void:
	node_type = "expression"
	time_dependent = true
	node_description = "Evaluate per-channel math expressions."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, true, "Input channels (optional)")
	add_output("out", GNFamily.Type.CHOP, "Expression result")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("expr", "sin(t * 3.0)",
		"Expression", "GDScript expression — available vars: v, i, n, t, dt, ch"))
	add_parameter(GNParameter.create_int("samples", 1, 1, 10000, "Samples",
		"Output sample count (if no input)"))
	add_parameter(GNParameter.create_string("channels", "chan1",
		"Channel names (comma-sep)", "Output channel names when no input"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	var expr_str: String = get_param_value("expr")
	var num_samples: int = maxi(get_param_value("samples"), 1)
	var ch_names_str: String = get_param_value("channels")
	var t: float = elapsed_time
	var dt: float = current_delta

	var out: GNChannelData = _prepare_output(60.0 if in_data == null else in_data.sample_rate)

	# Determine channel names and sample counts
	var channel_list: PackedStringArray
	var base_length: int

	if in_data != null:
		channel_list = in_data.get_channel_names()
		base_length = in_data.length
	else:
		channel_list = PackedStringArray()
		for part in ch_names_str.split(","):
			var trimmed: String = part.strip_edges()
			if not trimmed.is_empty():
				channel_list.append(trimmed)
		if channel_list.is_empty():
			channel_list.append("chan1")
		base_length = num_samples

	# Parse expression once
	var expression := Expression.new()
	var var_names: PackedStringArray = PackedStringArray(["v", "i", "n", "t", "dt", "ch"])
	var parse_err: Error = expression.parse(expr_str, var_names)
	if parse_err != OK:
		GNLogger.warn("ExpressionCHOP", "'%s' — parse error: %s" % [id, expression.get_error_text()])
		return null

	for ch_name in channel_list:
		var src_samples := PackedFloat32Array()
		if in_data != null and in_data.channels.has(ch_name):
			src_samples = in_data.channels[ch_name]

		var result := PackedFloat32Array()
		result.resize(base_length)

		for idx in range(base_length):
			var v: float = src_samples[idx] if idx < src_samples.size() else 0.0
			var values: Array = [v, float(idx), float(base_length), t, dt, ch_name]
			var res = expression.execute(values, self, false)
			if expression.has_execute_failed():
				result[idx] = 0.0
			elif res is float:
				result[idx] = res
			elif res is int:
				result[idx] = float(res)
			else:
				result[idx] = 0.0

		out.set_channel(ch_name, result)

	return out
