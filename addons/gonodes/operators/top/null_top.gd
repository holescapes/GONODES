class_name NullTOP
extends GNTopBase
## Pass-through TOP — forwards its input unchanged.


func _init() -> void:
	node_type = "null"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Same texture (pass-through)", "Out")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	return _null_cook(inputs)
