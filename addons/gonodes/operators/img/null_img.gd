class_name NullIMG
extends GNImgBase
## Pass-through IMG — forwards its input unchanged.


func _init() -> void:
	node_type = "null"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "Input image", "In")
	add_output("out", GNFamily.Type.IMG, "Same image (pass-through)", "Out")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	return _null_cook(inputs)
