class_name NullCHOP
extends GNChopBase
## Pass-through CHOP — forwards its input unchanged.


func _init() -> void:
	node_type = "null"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels")
	add_output("out", GNFamily.Type.CHOP, "Same channels (pass-through)")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	return _null_cook(inputs)
