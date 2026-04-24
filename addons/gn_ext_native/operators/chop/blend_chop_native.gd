class_name BlendCHOPNative
extends GNChopBase
## Native-accelerated channel blend — delegates to GNNativeBlendChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "blend_native"
	if ClassDB.class_exists("GNNativeBlendChop"):
		_processor = ClassDB.instantiate("GNNativeBlendChop")


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.CHOP, "in", "Input", 2)
	add_output("out", GNFamily.Type.CHOP, "Blended output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("weight", 0.5, 0.0, 1.0, 0.01,
		"Blend Weight", "0 = first input, 1 = last input"))
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["Linear", "Ease In", "Ease Out", "Smooth Step"]),
		0, "Method", "Interpolation curve"))


func _cook(inputs: Array[GNData]) -> GNData:
	var valid_inputs: Array[GNChannelData] = []
	for inp in inputs:
		if inp is GNChannelData:
			valid_inputs.append(inp as GNChannelData)
	if valid_inputs.is_empty():
		return null
	if valid_inputs.size() == 1:
		return valid_inputs[0]

	var weight: float = clampf(get_param_value("weight"), 0.0, 1.0)
	var method: int = get_param_value("method")
	var num: int = valid_inputs.size()
	var scaled: float = weight * (num - 1)
	var idx_a: int = clampi(int(scaled), 0, num - 2)
	var idx_b: int = idx_a + 1
	var t: float = scaled - idx_a
	match method:
		1: t = t * t
		2: t = 1.0 - (1.0 - t) * (1.0 - t)
		3: t = t * t * (3.0 - 2.0 * t)

	var data_a: GNChannelData = valid_inputs[idx_a]
	var data_b: GNChannelData = valid_inputs[idx_b]
	var out := _prepare_output(data_a.sample_rate)

	var all_ch: Dictionary = {}
	for ch in data_a.channels:
		all_ch[ch] = true
	for ch in data_b.channels:
		all_ch[ch] = true

	for ch_name in all_ch:
		var sa: PackedFloat32Array = data_a.channels.get(ch_name, PackedFloat32Array())
		var sb: PackedFloat32Array = data_b.channels.get(ch_name, PackedFloat32Array())
		if _processor != null:
			var arr: Array = [sa, sb]
			var wts := PackedFloat32Array([1.0 - t, t])
			out.channels[ch_name] = _processor.process(arr, wts)
		else:
			var max_len: int = maxi(sa.size(), sb.size())
			var blended := PackedFloat32Array()
			blended.resize(max_len)
			for i in range(max_len):
				var va: float = sa[i] if i < sa.size() else (sa[sa.size() - 1] if not sa.is_empty() else 0.0)
				var vb: float = sb[i] if i < sb.size() else (sb[sb.size() - 1] if not sb.is_empty() else 0.0)
				blended[i] = lerpf(va, vb, t)
			out.channels[ch_name] = blended

	return out
