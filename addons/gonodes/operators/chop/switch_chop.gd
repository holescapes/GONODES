class_name SwitchCHOP
extends GNNode
## Selects one of multiple CHOP inputs based on the index parameter.
## Number of inputs is controlled by the "num_inputs" parameter (2-8).


func _init() -> void:
	node_type = "switch"
	family = GNFamily.Type.CHOP
	node_description = "Select one of multiple CHOP inputs by index (dynamic port count)."


func _init_ports() -> void:
	add_input("in0", GNFamily.Type.CHOP, false, "Input 0")
	add_input("in1", GNFamily.Type.CHOP, false, "Input 1")
	add_output("out", GNFamily.Type.CHOP, "Selected input")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("num_inputs", 2, 2, 8, "Num Inputs",
		"Number of selectable CHOP inputs (2-8)"))
	add_parameter(GNParameter.create_int("index", 0, 0, 1, "Input Index",
		"Which input to output (0-based)"))


func _on_parameter_changed(param_name: String, _new_value: Variant) -> void:
	if param_name == "num_inputs":
		var count: int = get_param_value("num_inputs")
		set_input_count(count, GNFamily.Type.CHOP, "in", "Input")
		var idx_param := get_parameter("index")
		if idx_param:
			idx_param.max_value = count - 1
			if int(idx_param.value) >= count:
				idx_param.set_value(count - 1)
	mark_dirty()
	parameter_changed.emit(id, param_name)


func _cook(inputs: Array[GNData]) -> GNData:
	var idx: int = get_param_value("index")
	idx = clampi(idx, 0, inputs.size() - 1)

	if idx < inputs.size() and inputs[idx] is GNChannelData:
		return inputs[idx]

	# Fallback: return first valid input
	for inp in inputs:
		if inp is GNChannelData:
			return inp
	return null
