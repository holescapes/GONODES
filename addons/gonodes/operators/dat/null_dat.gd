class_name NullDAT
extends GNDatBase
## Pass-through DAT — forwards its input unchanged.


func _init() -> void:
	node_type = "null"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Input table", "In")
	add_output("out", GNFamily.Type.DAT, "Same table (pass-through)", "Out")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	return _null_cook(inputs)
