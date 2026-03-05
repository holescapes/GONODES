class_name SwitchCOMP
extends GNCompBase
## Switches between multiple component inputs.
##
## Routes one of up to 8 component inputs to the output based on the
## selected index parameter. Out-of-range indices are clamped.


func _init() -> void:
	node_type = "switch"
	node_description = "Select one of multiple component inputs."


func _init_ports() -> void:
	for i in range(8):
		add_input("in%d" % i, GNFamily.Type.COMP, false, "Component input %d" % i)
	add_output("out", GNFamily.Type.COMP, "Selected component")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("index", 0, 0, 7, "Input Index", "Which input to pass through"))


func _cook(inputs: Array[GNData]) -> GNData:
	var idx: int = clampi(get_param_value("index"), 0, inputs.size() - 1)
	if idx < inputs.size() and inputs[idx] != null:
		return inputs[idx]
	return null
