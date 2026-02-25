class_name MergeCHOP
extends GNChopBase
## Merges channels from multiple CHOP inputs into a single output.
## Channels with matching names can be overwritten or renamed.
## Number of inputs is controlled by the "num_inputs" parameter (2-8).


func _init() -> void:
	node_type = "merge"
	node_description = "Merge channels from multiple CHOP inputs (dynamic port count)."


func _init_ports() -> void:
	add_input("in0", GNFamily.Type.CHOP, false, "Input channels 0")
	add_input("in1", GNFamily.Type.CHOP, false, "Input channels 1")
	add_output("out", GNFamily.Type.CHOP, "Merged channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("num_inputs", 2, 2, 8, "Num Inputs",
		"Number of CHOP inputs to merge (2-8)"))
	add_parameter(GNParameter.create_enum("duplicate",
		PackedStringArray(["Overwrite", "Rename"]), 0, "",
		"How to handle duplicate channel names"))


func _on_parameter_changed(param_name: String, _new_value: Variant) -> void:
	if param_name == "num_inputs":
		var count: int = get_param_value("num_inputs")
		set_input_count(count, GNFamily.Type.CHOP, "in", "Input channels")
	mark_dirty()
	parameter_changed.emit(id, param_name)


func _cook(inputs: Array[GNData]) -> GNData:
	var dup_mode: int = get_param_value("duplicate")

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = 60.0

	var any_valid: bool = false

	for inp in inputs:
		var ch_data: GNChannelData = inp as GNChannelData if inp is GNChannelData else null
		if ch_data == null:
			continue

		any_valid = true
		_cached_channel_data.sample_rate = ch_data.sample_rate

		for ch_name in ch_data.channels:
			var out_name: String = ch_name
			if dup_mode == 1:
				var suffix_idx: int = 1
				while _cached_channel_data.channels.has(out_name):
					out_name = "%s_%d" % [ch_name, suffix_idx]
					suffix_idx += 1

			_cached_channel_data.set_channel(out_name, ch_data.channels[ch_name])

	if not any_valid:
		return null
	return _cached_channel_data
