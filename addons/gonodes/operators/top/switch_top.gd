class_name SwitchTOP
extends GNTopBase
## Selects one of multiple TOP inputs based on the index parameter.
## Like TouchDesigner's Switch TOP.  Uses dynamic auto-grow input ports —
## connect to add more slots, disconnect to shrink.


func _init() -> void:
	node_type = "switch"


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.TOP, "in", "Texture Input")
	add_output("out", GNFamily.Type.TOP, "Selected texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("index", 0, 0, 0, "Input Index",
		"Which input to output (0-based)"))
	add_parameter(GNParameter.create_bool("blend", false, "Blend Between",
		"Blend between adjacent inputs (stub)"))


## Auto-adjust index param max_value when ports grow/shrink.
func update_dynamic_inputs(connected_ports: PackedInt32Array) -> void:
	super(connected_ports)
	var idx_param := get_parameter("index")
	if idx_param:
		var max_idx: int = maxi(input_ports.size() - 2, 0)  # exclude trailing empty
		idx_param.max_value = max_idx
		if int(idx_param.value) > max_idx:
			idx_param.set_value(max_idx)


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
