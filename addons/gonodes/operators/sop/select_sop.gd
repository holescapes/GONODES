class_name SelectSOP
extends GNSopBase
## Wireless reference — returns a named remote SOP node's output directly.
##
## Set the 'sop' parameter to the node id of the source SOP.
## Use FilterSOP after this node to filter geometry elements.
##
## Rule: only Select nodes do wireless referencing — no wire input.

var _network_cache: GNNetwork = null


func _init() -> void:
	node_type = "select"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Referenced SOP output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("sop", GNFamily.Type.SOP,
		"SOP", "Node id of the remote SOP to reference"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var remote_id: String = get_param_value("sop")
	if remote_id.is_empty():
		node_warning = "No node reference specified"
		return null
	var data: GNGeoData = _resolve_remote_sop(remote_id)
	if data == null:
		node_warning = "Remote SOP '%s' not found or has no output" % remote_id
		return null
	node_warning = ""
	return data


func _resolve_remote_sop(target_id: String) -> GNGeoData:
	if _network_cache == null or not is_instance_valid(_network_cache):
		var p = get_parent()
		while p != null and not (p is GNNetwork):
			p = p.get_parent()
		_network_cache = p as GNNetwork
	if _network_cache == null:
		return null
	var target: GNNode = _network_cache.get_node_by_id(target_id)
	if target == null:
		return null
	var _ret0 := target.cached_output as GNGeoData if target.cached_output is GNGeoData else null
	return _ret0
