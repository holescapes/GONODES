class_name CopyCHOP
extends GNChopBase
## Copies channels from input B onto input A, overwriting or adding values.
## Matching channels are combined; non-matching are passed through.


func _init() -> void:
	node_type = "copy"


func _init_ports() -> void:
	add_input("a", GNFamily.Type.CHOP, false, "Base channels (A)", "A")
	add_input("b", GNFamily.Type.CHOP, false, "Source channels (B)", "B")
	add_output("out", GNFamily.Type.CHOP, "Combined channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("operation",
		PackedStringArray(["Overwrite", "Add", "Subtract", "Multiply"]),
		0, "", "How B channels are applied to A"))
	add_parameter(GNParameter.create_bool("pass_non_matching", true, "Pass through channels not matching the pattern",
		"Pass A channels that have no match in B"))


func _cook(inputs: Array[GNData]) -> GNData:
	var data_a: GNChannelData = _get_input_chop(inputs, 0)
	var data_b: GNChannelData = _get_input_chop(inputs, 1)

	if data_a == null and data_b == null:
		return null

	var op: int = get_param_value("operation")
	var pass_non: bool = get_param_value("pass_non_matching")

	var sr: float = data_a.sample_rate if data_a != null else data_b.sample_rate
	var out: GNChannelData = _prepare_output(sr)

	# Start with A channels
	if data_a != null:
		for ch_name in data_a.channels:
			var samples_a: PackedFloat32Array = data_a.channels[ch_name]
			if data_b != null and data_b.channels.has(ch_name):
				var samples_b: PackedFloat32Array = data_b.channels[ch_name]
				out.set_channel(ch_name, _combine(samples_a, samples_b, op))
			elif pass_non:
				out.set_channel(ch_name, samples_a)

	# Add B-only channels (always passed through)
	if data_b != null:
		for ch_name in data_b.channels:
			if not out.channels.has(ch_name):
				out.set_channel(ch_name, data_b.channels[ch_name])

	return out


func _combine(a: PackedFloat32Array, b: PackedFloat32Array, op: int) -> PackedFloat32Array:
	var len_out: int = maxi(a.size(), b.size())
	var result := PackedFloat32Array()
	result.resize(len_out)

	for i in range(len_out):
		var va: float = a[clampi(i, 0, a.size() - 1)] if not a.is_empty() else 0.0
		var vb: float = b[clampi(i, 0, b.size() - 1)] if not b.is_empty() else 0.0
		match op:
			0:  result[i] = vb          # Overwrite
			1:  result[i] = va + vb     # Add
			2:  result[i] = va - vb     # Subtract
			3:  result[i] = va * vb     # Multiply
			_:  result[i] = vb

	return result
