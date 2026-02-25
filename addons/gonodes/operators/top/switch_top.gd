class_name SwitchTOP
extends GNNode
## Selects one of multiple TOP inputs based on the index parameter.
## Like TouchDesigner's Switch TOP.  The number of inputs is controlled
## by the "num_inputs" parameter (2-8) so unused SubViewports are not created.


func _init() -> void:
	node_type = "switch"
	family = GNFamily.Type.TOP
	node_description = "Select one of multiple texture inputs by index (dynamic port count)."


func _init_ports() -> void:
	# Start with 2 inputs — user adjusts via num_inputs parameter
	add_input("in0", GNFamily.Type.TOP, false, "Texture input 0")
	add_input("in1", GNFamily.Type.TOP, false, "Texture input 1")
	add_output("out", GNFamily.Type.TOP, "Selected texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("num_inputs", 2, 2, 8, "Num Inputs",
		"Number of selectable texture inputs (2-8)"))
	add_parameter(GNParameter.create_int("index", 0, 0, 1, "Input Index",
		"Which input to output (0-based)"))
	add_parameter(GNParameter.create_bool("blend", false, "Blend Between",
		"Blend between adjacent inputs (stub)"))


func _on_parameter_changed(param_name: String, _new_value: Variant) -> void:
	if param_name == "num_inputs":
		var count: int = get_param_value("num_inputs")
		set_input_count(count, GNFamily.Type.TOP, "in", "Texture input")
		# Clamp index param range to match new input count
		var idx_param := get_parameter("index")
		if idx_param:
			idx_param.max_value = count - 1
			if int(idx_param.value) >= count:
				idx_param.set_value(count - 1)
	mark_dirty()
	parameter_changed.emit(id, param_name)


func _cook(inputs: Array[GNData]) -> GNData:
	var idx: int = get_param_value("index")
	var do_blend: bool = get_param_value("blend")

	if not do_blend:
		idx = clampi(idx, 0, inputs.size() - 1)
		if idx < inputs.size() and inputs[idx] is GNTextureData:
			return inputs[idx]
		# Fallback: return first valid input
		for inp in inputs:
			if inp is GNTextureData:
				return inp
		return null
	else:
		idx = clampi(idx, 0, inputs.size() - 1)
		if idx < inputs.size() and inputs[idx] is GNTextureData:
			return inputs[idx]
		return null
