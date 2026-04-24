class_name InterpolateCHOPNative
extends GNChopBase
## Native-accelerated interpolation — delegates to GNNativeInterpolateChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "interpolate_native"
	node_description = "Blend between two channel inputs with easing — native C++ accelerated."
	if ClassDB.class_exists("GNNativeInterpolateChop"):
		_processor = ClassDB.instantiate("GNNativeInterpolateChop")


func _init_ports() -> void:
	add_input("a", GNFamily.Type.CHOP, false, "Channel set A")
	add_input("b", GNFamily.Type.CHOP, false, "Channel set B")
	add_output("out", GNFamily.Type.CHOP, "Blended channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("blend", 0.5, 0.0, 1.0, 0.01,
		"Blend (0=A, 1=B)", "Interpolation factor"))
	add_parameter(GNParameter.create_enum("curve",
		PackedStringArray(["Linear", "Ease In", "Ease Out", "Ease In-Out", "Smooth Step"]),
		0, "", "Easing curve"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_a: GNChannelData = _get_input_chop(inputs, 0)
	var in_b: GNChannelData = _get_input_chop(inputs, 1)
	if in_a == null:
		return null
	if in_b == null:
		return in_a

	var blend_val: float = get_param_value("blend")
	var curve: int = get_param_value("curve")

	if _processor != null:
		var ch_a := {}
		for ch_name in in_a.channels:
			ch_a[ch_name] = in_a.channels[ch_name]
		var ch_b := {}
		for ch_name in in_b.channels:
			ch_b[ch_name] = in_b.channels[ch_name]
		var result: Dictionary = _processor.process(ch_a, ch_b, blend_val, curve)
		var out: GNChannelData = _prepare_output(in_a.sample_rate)
		for key in result:
			out.channels[key] = result[key]
		out.length = in_a.length
		return out
	else:
		return null
