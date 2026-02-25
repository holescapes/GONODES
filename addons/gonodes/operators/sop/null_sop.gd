class_name NullSOP
extends GNSopBase
## Pass-through SOP — forwards its input geometry unchanged.

func _init() -> void:
	node_type = "null"
	node_description = "Pass-through for organization and references."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Same geometry (pass-through)")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	if inputs.size() > 0 and inputs[0] is GNGeoData:
		return inputs[0]
	return null
