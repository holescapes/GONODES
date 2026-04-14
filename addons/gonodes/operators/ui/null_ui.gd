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
	var upstream: GNUiBase = get_input_node(0) as GNUiBase if get_input_node(0) is GNUiBase else null
	if upstream != null:
		var ctrl: Control = upstream.get_control_node()
		if ctrl != null:
			_control_node = ctrl
			widget_state = upstream.widget_state.duplicate() if upstream.widget_state != null else {}
			return null  # UI output routed via get_control_node()

	# No input — output nothing (null source for gating)
	_control_node = null
	widget_state = {}
	return null
