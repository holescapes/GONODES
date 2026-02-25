class_name SwitchSOP
extends GNNode
## Switches between multiple SOP inputs based on an index.
## Number of inputs is controlled by the "num_inputs" parameter (2-8).

func _init() -> void:
	node_type = "switch"
	family = GNFamily.Type.SOP
	node_description = "Switch between multiple SOP inputs by index (dynamic port count)."


func _init_ports() -> void:
	add_input("in0", GNFamily.Type.SOP, false, "Input 0")
	add_input("in1", GNFamily.Type.SOP, false, "Input 1")
	add_output("out", GNFamily.Type.SOP, "Selected input")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("num_inputs", 2, 2, 8, "Num Inputs",
		"Number of selectable SOP inputs (2-8)"))
	add_parameter(GNParameter.create_int("index", 0, 0, 1, "Index",
		"Which input to output (0-based)"))


func _on_parameter_changed(param_name: String, _new_value: Variant) -> void:
	if param_name == "num_inputs":
		var count: int = get_param_value("num_inputs")
		set_input_count(count, GNFamily.Type.SOP, "in", "Input")
		var idx_param := get_parameter("index")
		if idx_param:
			idx_param.max_value = count - 1
			if int(idx_param.value) >= count:
				idx_param.set_value(count - 1)
	mark_dirty()
	parameter_changed.emit(id, param_name)


func _cook(inputs: Array[GNData]) -> GNData:
	var idx: int = clampi(get_param_value("index"), 0, inputs.size() - 1)
	if idx < inputs.size() and inputs[idx] is GNGeoData:
		return inputs[idx]
	return null
