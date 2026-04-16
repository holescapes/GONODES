class_name NullUI
extends GNUiBase
## Pass-through UI — forwards its input widget unchanged.


func _init() -> void:
	node_type = "null"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.UI, false, "Input UI widget")
	add_output("out", GNFamily.Type.UI, "Same widget (pass-through)")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	if inputs.size() > 0 and inputs[0] is GNUIData:
		var uid: GNUIData = inputs[0] as GNUIData
		if uid.control_node != null:
			_control_node = uid.control_node
			widget_state = uid.widget_state.duplicate() if uid.widget_state != null else {}
			return null  # UI output routed via get_control_node()

	# No input — output nothing (null source for gating)
	_control_node = null
	widget_state = {}
	return null
