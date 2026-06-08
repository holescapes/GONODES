class_name CopyCHOPNative
extends GNChopBase
## Native-accelerated channel copy/combine — delegates to GNNativeCopyChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "copy_native"
	if ClassDB.class_exists("GNNativeCopyChop"):
		_processor = ClassDB.instantiate("GNNativeCopyChop")


func _init_ports() -> void:
	add_input("a", GNFamily.Type.CHOP, false, "Base channels (A)", "A")
	add_input("b", GNFamily.Type.CHOP, false, "Source channels (B)", "B")
	add_output("out", GNFamily.Type.CHOP, "Combined channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("operation",
		PackedStringArray(["Overwrite", "Add", "Subtract", "Multiply"]),
		0, "", "How B channels are applied to A"))
	add_parameter(GNParameter.create_bool("pass_non_matching", true, "",
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

	if _processor and data_a != null and data_b != null:
		# Native path: combine matching channels in C++
		var combined: Dictionary = _processor.process(data_a.channels, data_b.channels, op)
		for ch_name: String in combined:
			out.set_channel(ch_name, combined[ch_name])

		# Pass non-matching A channels
		if pass_non:
			for ch_name: String in data_a.channels:
				if not out.channels.has(ch_name):
					out.set_channel(ch_name, data_a.channels[ch_name])

		# Pass B-only channels
		for ch_name: String in data_b.channels:
			if not out.channels.has(ch_name):
				out.set_channel(ch_name, data_b.channels[ch_name])
	else:
		# Fallback: one input is null
		if data_a != null:
			for ch_name: String in data_a.channels:
				if pass_non:
					out.set_channel(ch_name, data_a.channels[ch_name])
		if data_b != null:
			for ch_name: String in data_b.channels:
				if not out.channels.has(ch_name):
					out.set_channel(ch_name, data_b.channels[ch_name])

	return out
