class_name NullVOL
extends GNVolBase
## Pass-through VOL — forwards volume data unchanged.


func _init() -> void:
	super._init()
	node_type = "null"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.VOL, false, "Input volume", "In")
	add_output("out", GNFamily.Type.VOL, "Same volume (pass-through)", "Out")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	return _null_cook(inputs)


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	return _null_cook(inputs)
