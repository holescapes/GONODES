class_name NullSOP
extends GNNode
## Pass-through SOP — forwards its input geometry unchanged.

func _init() -> void:
	node_type = "null"
	family = GNFamily.Type.SOP


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP)
	add_output("out", GNFamily.Type.SOP)


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	if inputs.size() > 0 and inputs[0] is GNGeoData:
		return inputs[0]
	return null
