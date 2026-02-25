class_name NullTOP
extends GNNode
## Pass-through TOP — forwards its input unchanged.
## Useful for organizing networks, creating reference points,
## and as merge targets.

var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "null"
	family = GNFamily.Type.TOP
	node_description = "Pass-through. Useful for organization and expression references."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Same texture (pass-through)")


func _init_parameters() -> void:
	pass  # No parameters — pure pass-through


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		return null
	return tex_in
