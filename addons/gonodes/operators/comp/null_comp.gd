class_name NullCOMP
extends GNCompBase
## Pass-through component that does nothing.
##
## Wire-cleanup / organizational node. Passes input data through unchanged.
## Useful for tidying networks or as a placeholder during prototyping.


func _init() -> void:
	node_type = "null"
	node_description = "Pass-through component for wire organization."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.COMP, false, "Input component")
	add_output("out", GNFamily.Type.COMP, "Pass-through output")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	if inputs.size() > 0 and inputs[0] != null:
		return inputs[0]
	return null
