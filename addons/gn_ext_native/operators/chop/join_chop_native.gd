class_name JoinCHOPNative
extends GNChopBase
## Native-accelerated channel joining — delegates to GNNativeJoinChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "join_native"
	if ClassDB.class_exists("GNNativeJoinChop"):
		_processor = ClassDB.instantiate("GNNativeJoinChop")


func _init_ports() -> void:
	add_input("A", GNFamily.Type.CHOP, false, "First input")
	add_input("B", GNFamily.Type.CHOP, false, "Second input")
	add_output("out", GNFamily.Type.CHOP, "Joined output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("overlap", 0, 0, 10000,
		"Overlap", "Number of samples to crossfade between A and B"))


func _cook(inputs: Array[GNData]) -> GNData:
	var chop_a := _get_input_chop(inputs, 0)
	var chop_b := _get_input_chop(inputs, 1)
	if not chop_a:
		return chop_b
	if not chop_b:
		return chop_a
	if not _processor:
		return null

	var overlap: int = get_param_value("overlap")
	var result: Dictionary = _processor.process(chop_a.channels, chop_b.channels, overlap)
	var out := _prepare_output(chop_a.sample_rate)
	for ch_name in result:
		out.channels[ch_name] = result[ch_name]
	if result.size() > 0:
		for ch_name in result:
			out.length = (result[ch_name] as PackedFloat32Array).size()
			break
	return out
