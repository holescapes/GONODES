class_name LookupCHOP
extends GNChopBase
## Uses the value from one CHOP to index into the sample array of another.
## Input 1 = index channel(s) (0-1 normalised), Input 0 = lookup table.


func _init() -> void:
	node_type = "lookup"
	node_description = "Index into a sample array using another channel's value."


func _init_ports() -> void:
	add_input("table", GNFamily.Type.CHOP, false, "Lookup table (multi-sample)")
	add_input("index", GNFamily.Type.CHOP, false, "Index values (0-1)")
	add_output("out", GNFamily.Type.CHOP, "Looked-up values")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("interpolate",
		PackedStringArray(["Linear", "Nearest"]), 0, "",
		"Interpolation between samples"))
	add_parameter(GNParameter.create_enum("extend",
		PackedStringArray(["Clamp", "Cycle", "Mirror"]), 0, "",
		"Behaviour when index is outside 0-1"))


func _cook(inputs: Array[GNData]) -> GNData:
	var table_data: GNChannelData = _get_input_chop(inputs, 0)
	var index_data: GNChannelData = _get_input_chop(inputs, 1)
	if table_data == null or index_data == null:
		return null

	var interp_mode: int = get_param_value("interpolate")
	var extend_mode: int = get_param_value("extend")
	var out: GNChannelData = _prepare_output(index_data.sample_rate)

	for ch_name in index_data.channels:
		var idx_samples: PackedFloat32Array = index_data.channels[ch_name]
		# Try to find a matching table channel, else use first available
		var table_ch: PackedFloat32Array
		if table_data.channels.has(ch_name):
			table_ch = table_data.channels[ch_name]
		else:
			var names := table_data.get_channel_names()
			if names.is_empty():
				continue
			table_ch = table_data.channels[names[0]]

		if table_ch.is_empty():
			continue

		var result := PackedFloat32Array()
		result.resize(idx_samples.size())
		var tlen: int = table_ch.size()

		for i in range(idx_samples.size()):
			var t: float = idx_samples[i]

			# Apply extend mode
			t = _extend(t, extend_mode)

			var fpos: float = t * (tlen - 1)
			if interp_mode == 1:
				# Nearest
				var idx: int = clampi(roundi(fpos), 0, tlen - 1)
				result[i] = table_ch[idx]
			else:
				# Linear interpolation
				var lo: int = clampi(int(fpos), 0, tlen - 1)
				var hi: int = clampi(lo + 1, 0, tlen - 1)
				var frac: float = fpos - float(lo)
				result[i] = lerpf(table_ch[lo], table_ch[hi], clampf(frac, 0.0, 1.0))

		out.set_channel(ch_name, result)

	return out


func _extend(t: float, mode: int) -> float:
	match mode:
		0:  # Clamp
			return clampf(t, 0.0, 1.0)
		1:  # Cycle
			return fmod(fmod(t, 1.0) + 1.0, 1.0)
		2:  # Mirror
			var m: float = fmod(absf(t), 2.0)
			return m if m <= 1.0 else 2.0 - m
		_:
			return clampf(t, 0.0, 1.0)
