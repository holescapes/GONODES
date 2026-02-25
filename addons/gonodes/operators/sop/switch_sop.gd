class_name SwitchSOP
extends GNNode
## Switches between two SOP inputs based on an index.

func _init() -> void:
	node_type = "switch"
	family = GNFamily.Type.SOP


func _init_ports() -> void:
	add_input("in0", GNFamily.Type.SOP)
	add_input("in1", GNFamily.Type.SOP)
	add_output("out", GNFamily.Type.SOP)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("index", 0, 0, 1, "Index"))


func _cook(inputs: Array[GNData]) -> GNData:
	var idx: int = clampi(get_param_value("index"), 0, 1)
	if idx < inputs.size() and inputs[idx] is GNGeoData:
		return inputs[idx]
	return null
