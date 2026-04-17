class_name GNCompRenderer
extends GNDataRenderer
## Renders GNCompData in the viewer.
## COMPs that pass through upstream data (GNGeoData, GNTextureData, etc.)
## are handled automatically by the GNNode base dispatcher — the data type's
## own renderer takes over.  This renderer handles only the "pure COMP" case
## where the output is GNCompData itself (scene node info).


func supports_wireframe() -> bool:
	return false


func render_for_viewer(data: GNData, viewer) -> void:
	if data is GNCompData:
		var cd: GNCompData = data as GNCompData
		if cd.scene_node != null:
			var vis: String = "visible" if cd.scene_node.visible else "hidden"
			viewer.set_info("%s\n%s" % [cd.scene_label, vis], "COMP")
			return
	viewer.set_info("COMP", "Component operator")


func render_for_preview(data: GNData, host) -> void:
	if data is GNCompData:
		var cd: GNCompData = data as GNCompData
		if cd.scene_node != null and host.has_method("set_text"):
			var vis: String = "visible" if cd.scene_node.visible else "hidden"
			host.set_text("%s\n%s" % [cd.scene_label, vis])
			return
	if host.has_method("set_text"):
		host.set_text("no node")
