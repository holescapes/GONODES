class_name NullIMG
extends GNImgBase
## Pass-through IMG — forwards its input unchanged.
## Useful for organizing networks and creating reference points.


func _init() -> void:
	node_type = "null"
	node_description = "Pass-through for organization and references."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "Input image")
	add_output("out", GNFamily.Type.IMG, "Same image (pass-through)")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	if inputs.size() > 0 and inputs[0] is GNImageData:
		return inputs[0]
	return null
