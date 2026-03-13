class_name ResampleCHOPNative
extends GNChopBase
## Native-accelerated resampling — delegates to GNNativeResampleChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "resample"
	node_description = "Resample channels to new length or rate — native C++ accelerated."
	if ClassDB.class_exists("GNNativeResampleChop"):
		_processor = ClassDB.instantiate("GNNativeResampleChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels")
	add_output("out", GNFamily.Type.CHOP, "Resampled channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["To Samples", "To Rate"]), 0, "", "Resample mode"))
	add_parameter(GNParameter.create_int("samples", 60, 1, 100000, "Samples", "Target sample count"))
	add_parameter(GNParameter.create_float("rate", 60.0, 1.0, 48000.0, 1.0, "Rate (Hz)", "Target sample rate"))
	add_parameter(GNParameter.create_enum("quality",
		PackedStringArray(["Linear", "Cubic", "Nearest"]), 0, "", "Interpolation quality"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var method: int = get_param_value("method")
	var target_samples: int = get_param_value("samples")
	var target_rate: float = get_param_value("rate")
	var quality: int = get_param_value("quality")

	if method == 1 and in_data.length > 0 and in_data.sample_rate > 0.0:
		target_samples = int(float(in_data.length) / in_data.sample_rate * target_rate)
		target_samples = maxi(target_samples, 1)

	if _processor != null:
		var channels := {}
		for ch_name in in_data.channels:
			channels[ch_name] = in_data.channels[ch_name]
		var result: Dictionary = _processor.process(channels, target_samples, quality)
		var out_rate: float = target_rate if method == 1 else in_data.sample_rate
		var out: GNChannelData = _prepare_output(out_rate)
		for key in result:
			out.channels[key] = result[key]
		out.length = target_samples
		return out
	else:
		return null
