class_name SwitchCHOP
extends GNNode
## Selects one of multiple CHOP inputs based on the index parameter.
## Similar to TouchDesigner's Switch CHOP.


func _init() -> void:
	node_type = "switch"
	family = GNFamily.Type.CHOP


func _init_ports() -> void:
	add_input("in0", GNFamily.Type.CHOP)
	add_input("in1", GNFamily.Type.CHOP)
	add_input("in2", GNFamily.Type.CHOP)
	add_input("in3", GNFamily.Type.CHOP)
	add_output("out", GNFamily.Type.CHOP)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("index", 0, 0, 3, "Input Index"))


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
