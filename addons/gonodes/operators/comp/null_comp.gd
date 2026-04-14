class_name NullCOMP
extends GNCompBase
## Pass-through COMP — forwards its input unchanged.


func _init() -> void:
	node_type = "null"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.COMP, false, "Input component")
	add_output("out", GNFamily.Type.COMP, "Pass-through output")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	return _null_cook(inputs)
