class_name SwitchTOP
extends GNNode
## Selects one of multiple TOP inputs based on the index parameter.
## Like TouchDesigner's Switch TOP.

func _init() -> void:
	node_type = "switch"
	family = GNFamily.Type.TOP


func _init_ports() -> void:
	add_input("in0", GNFamily.Type.TOP)
	add_input("in1", GNFamily.Type.TOP)
	add_input("in2", GNFamily.Type.TOP)
	add_input("in3", GNFamily.Type.TOP)
	add_output("out", GNFamily.Type.TOP)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("index", 0, 0, 3, "Input Index"))
	add_parameter(GNParameter.create_bool("blend", false, "Blend Between"))


func _cook(inputs: Array[GNData]) -> GNData:
	var idx: int = get_param_value("index")
	var do_blend: bool = get_param_value("blend")

	if not do_blend:
		# Simple switch — just pick the indexed input
		idx = clampi(idx, 0, inputs.size() - 1)
		if idx < inputs.size() and inputs[idx] is GNTextureData:
			return inputs[idx]
		# Fallback: return first valid input
		for inp in inputs:
			if inp is GNTextureData:
				return inp
		return null
	else:
		# Blend mode: crossfade between idx and idx+1
		# For now, just return the indexed one (blend requires shader)
		idx = clampi(idx, 0, inputs.size() - 1)
		if idx < inputs.size() and inputs[idx] is GNTextureData:
			return inputs[idx]
		return null
