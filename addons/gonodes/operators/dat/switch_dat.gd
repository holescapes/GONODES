class_name SwitchDAT
extends GNNode
## Switches between two DAT inputs based on an index parameter.

var _cached_table: GNTableData = null


func _init() -> void:
	node_type = "switch"
	family = GNFamily.Type.DAT


func _init_ports() -> void:
	add_input("in0", GNFamily.Type.DAT)
	add_input("in1", GNFamily.Type.DAT)
	add_output("out", GNFamily.Type.DAT)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("index", 0, 0, 1, "Index"))


func _cook(inputs: Array[GNData]) -> GNData:
	var idx: int = clampi(get_param_value("index"), 0, 1)
	if idx < inputs.size() and inputs[idx] is GNTableData:
		return inputs[idx]
	return null
