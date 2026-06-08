class_name NullMAT
extends GNMatBase
## Pass-through MAT — forwards material data unchanged.


func _init() -> void:
	node_type = "null"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.MAT, false, "Input material", "In")
	add_output("out", GNFamily.Type.MAT, "Same material (pass-through)", "Out")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	return _null_cook(inputs)
