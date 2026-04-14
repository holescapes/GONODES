class_name GNUIRenderer
extends GNDataRenderer
## Renders GNUIData in the viewer (embedded Control duplicate + widget state).


func render_for_viewer(data: GNData, viewer) -> void:
	if data is GNUIData:
		var ud: GNUIData = data as GNUIData
		if ud.control_node != null:
			var preview: Control = ud.control_node.duplicate()
			var info := ud.control_label if not ud.control_label.is_empty() else ud.control_node.get_class()
			viewer.set_control(preview, info)
			return
	viewer.set_info("No UI output", "")


func render_for_preview(data: GNData, host) -> void:
	if data is GNUIData:
		var ud: GNUIData = data as GNUIData
		if ud.control_node != null and host.has_method("set_text"):
			host.set_text("%s\n%s" % [ud.control_node.get_class(), ud.control_label])
			return
	if host.has_method("set_text"):
		host.set_text("no widget")
