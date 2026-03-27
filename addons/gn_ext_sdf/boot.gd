## SDF extension boot script — registers a viewer display handler for GNSDFData
## so the core viewer panel knows how to display SDF tree output.
##
## Uses late-binding (no static type references to UI classes) so this script
## can parse in headless mode where UI classes are not available.
extends RefCounted


static func boot() -> void:
	# Skip registration in headless mode — the viewer panel references UI classes
	# (SubViewport, Camera3D) that cause Godot warnings when loaded headless.
	if DisplayServer.get_name() == "headless":
		return
	var vp_script = load("res://addons/gonodes/ui/gn_viewer_panel.gd")
	if vp_script == null:
		return
	if vp_script.has_method("register_display_handler"):
		vp_script.register_display_handler("GNSDFData", _display_sdf)


static func _display_sdf(output, viewer) -> void:
	if output == null:
		viewer.show_info("Empty SDF tree", "")
		return
	var tree = output.get("sdf_tree")
	if tree == null or tree.is_empty():
		viewer.show_info("Empty SDF tree", "")
	else:
		viewer.show_info(output.get_preview_text(), "hash: %d" % output.get("tree_hash"))
