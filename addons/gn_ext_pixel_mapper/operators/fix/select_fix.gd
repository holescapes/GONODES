class_name SelectFIX
extends GNFixtureBase
## Wireless fixture reference.
## Re-emits a named FIX node's output without a wire.
## Only Select nodes do wireless referencing — Rule 25.35.


func _init() -> void:
	super._init()
	node_type = "select_fix"
	node_description = "Wireless FIX reference — re-emits a named fixture node's output without a wire."


func _init_ports() -> void:
	add_output("out", GNFixtureBase.FIX_FAMILY, "Fixture output from referenced node")


func _init_parameters() -> void:
	var p := GNParameter.create_node_ref("fix", GNFixtureBase.FIX_FAMILY,
		"Source", "FIX node to reference wirelessly.")
	add_parameter(p)


func _cook(_inputs: Array[GNData]) -> GNData:
	var target_id: String = get_param_value("fix")
	if target_id.is_empty():
		node_warning = "No source node set."
		return null
	var net: GNNetwork = _get_network()
	if net == null:
		node_warning = "Cannot find parent network."
		return null
	var target: GNNode = net.get_node(target_id)
	if target == null:
		node_warning = "Node '%s' not found." % target_id
		return null
	node_warning = ""
	return target.cached_output
