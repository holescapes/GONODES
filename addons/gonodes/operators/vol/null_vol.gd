class_name NullVOL
extends GNVolBase
## Pass-through VOL — forwards volume data unchanged.
## Useful for organizing networks and creating reference points.


func _init() -> void:
	super._init()
	node_type = "null"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.VOL, false, "Input volume")
	add_output("out", GNFamily.Type.VOL, "Same volume (pass-through)")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	if inputs.size() > 0 and inputs[0] is GNVolumeData:
		return inputs[0]
	return null


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	if inputs.size() > 0 and inputs[0] is GNVolumeData:
		return inputs[0]
	return null
