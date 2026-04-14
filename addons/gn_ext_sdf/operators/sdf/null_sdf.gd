class_name NullSDF
extends GNSdfBase
## Pass-through SDF — forwards its input SDF tree unchanged.


func _init() -> void:
	super._init()
	node_type = "null_sdf"


func _init_ports() -> void:
	add_input("in", SDF_FAMILY, false, "Input SDF tree")
	add_output("out", SDF_FAMILY, "Same SDF tree (pass-through)")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	return _null_cook(inputs)
