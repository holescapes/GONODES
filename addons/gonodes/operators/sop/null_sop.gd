class_name NullSOP
extends GNSopBase
## Pass-through SOP — forwards its input geometry unchanged.

func _init() -> void:
	node_type = "null"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Same geometry (pass-through)", "Out")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	return _null_cook(inputs)
