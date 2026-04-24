class_name NoiseCHOPNative
extends GNChopBase
## Native-accelerated noise CHOP — delegates to GNNativeNoiseChop (C++)
## when available, falls back to pure GDScript otherwise.

var _processor: RefCounted = null
var _time_accum: float = 0.0


func _init() -> void:
	node_type = "noise_native"
	time_dependent = true
	node_description = "Generate smooth noise channels over time — native C++ accelerated."
	if ClassDB.class_exists("GNNativeNoiseChop"):
		_processor = ClassDB.instantiate("GNNativeNoiseChop")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Noise channel data")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("num_channels", 1, 1, 16, "", "Number of noise channels"))
	add_parameter(GNParameter.create_string("channel_names", "chan1",
		"Channel Names", "Comma-separated channel names"))
	add_parameter(GNParameter.create_float("roughness", 0.5, 0.0, 1.0, 0.01, "", "Octave detail"))
	add_parameter(GNParameter.create_float("period", 1.0, 0.01, 100.0, 0.01, "", "Time period"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 99999, "", "Random seed"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var num_ch: int = get_param_value("num_channels")
	var roughness: float = get_param_value("roughness")
	var period: float = get_param_value("period")
	var seed_val: int = get_param_value("seed")

	_time_accum += current_delta

	if _processor != null:
		var result: Dictionary = _processor.process(num_ch, _time_accum, period, roughness, seed_val)
		var names_str: String = get_param_value("channel_names")
		var ch_names := _parse_channel_names(names_str, num_ch)

		var out: GNChannelData = _prepare_output(60.0)
		var idx := 0
		for key in result:
			var ch_name: String = ch_names[idx] if idx < ch_names.size() else key
			out.channels[ch_name] = result[key]
			idx += 1
		out.length = 1
		return out
	else:
		return null


func _parse_channel_names(names_str: String, count: int) -> PackedStringArray:
	var names := PackedStringArray()
	if not names_str.is_empty():
		for part in names_str.split(","):
			names.append(part.strip_edges())
	while names.size() < count:
		names.append("chan%d" % (names.size() + 1))
	return names
