class_name NullMAT
extends GNMatBase
## Pass-through MAT — forwards material data unchanged.
## Useful for organizing networks and creating reference points.


func _init() -> void:
	node_type = "null"
	node_description = "Pass-through for organization and references."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.MAT, false, "Input material")
	add_output("out", GNFamily.Type.MAT, "Same material (pass-through)")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	if inputs.size() > 0 and inputs[0] is GNMaterialData:
		return inputs[0]
	return null
