class_name SwitchCHOP
extends GNChopBase
## Selects one of multiple CHOP inputs based on the index parameter.
## Uses dynamic auto-grow input ports — connect to add more slots.


func _init() -> void:
	node_type = "switch"


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.CHOP, "in", "Input")
	add_output("out", GNFamily.Type.CHOP, "Selected input")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("index", 0, 0, 0, "Input Index",
		"Which input to output (0-based)"))


## Auto-adjust index param max_value when ports grow/shrink.
func update_dynamic_inputs(connected_ports: PackedInt32Array) -> void:
	super(connected_ports)
	var idx_param := get_parameter("index")
	if idx_param:
		var max_idx: int = maxi(input_ports.size() - 2, 0)
		idx_param.max_value = max_idx
		if int(idx_param.value) > max_idx:
			idx_param.set_value(max_idx)


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
