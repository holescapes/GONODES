class_name NullDAT
extends GNDatBase
## Pass-through DAT — forwards its input unchanged.
## Useful for organizing networks and creating reference points.


func _init() -> void:
	node_type = "null"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Input table")
	add_output("out", GNFamily.Type.DAT, "Same table (pass-through)")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	if inputs.size() > 0 and inputs[0] is GNTableData:
		return inputs[0]
	return null
