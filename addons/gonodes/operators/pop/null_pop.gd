class_name NullPOP
extends GNPopBase
## Pass-through POP — forwards particle data unchanged.
## Essential for feedback loops (simulation reads previous frame from NullPOP)
## and for organizing particle networks.


func _init() -> void:
	super._init()
	node_type = "null"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.POP, false, "Input particles")
	add_output("out", GNFamily.Type.POP, "Same particles (pass-through)")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	if inputs.size() > 0 and inputs[0] is GNParticleData:
		return inputs[0]
	return null


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	if inputs.size() > 0 and inputs[0] is GNParticleData:
		return inputs[0]
	return null
