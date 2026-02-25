class_name NullCHOP
extends GNNode
## Pass-through CHOP — forwards its input unchanged.
## Useful for organizing networks and creating reference points.


func _init() -> void:
	node_type = "null"
	family = GNFamily.Type.CHOP
	node_description = "Pass-through for organization and references."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels")
	add_output("out", GNFamily.Type.CHOP, "Same channels (pass-through)")


func _init_parameters() -> void:
	pass  # No parameters — pure pass-through


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	if in_data == null:
		return null
	return in_data
