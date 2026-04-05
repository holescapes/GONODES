class_name SelectSDF
extends GNSdfBase
## References a remote SDF node by name — outputs that node's SDF tree
## without requiring a wire connection.
##
## When the 'sdf' parameter names a remote SDF, its output is used.
## When 'sdf' is empty, the wired input is used instead (pass-through).

var _network_cache: GNNetwork = null


func _init() -> void:
	super._init()
	node_type = "select"


func _init_ports() -> void:
	add_input("in", SDF_FAMILY, false, "Input SDF (used when 'sdf' is empty)")
	add_output("out", SDF_FAMILY, "Selected SDF tree")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("sdf", SDF_FAMILY,
		"SDF", "Name (id) of a remote SDF to reference (empty = use wired input)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var remote_id: String = get_param_value("sdf")

	if not remote_id.is_empty():
		var data: GNData = _resolve_remote(remote_id)
		if data is GNSDFData:
			node_warning = ""
			return data
		node_warning = "Remote SDF '%s' not found or has no output" % remote_id
		return null

	node_warning = ""
	if inputs.size() > 0 and inputs[0] is GNSDFData:
		return inputs[0]
	return null


func _resolve_remote(target_id: String) -> GNData:
	if _network_cache == null or not is_instance_valid(_network_cache):
		var p = get_parent()
		while p != null and not (p is GNNetwork):
			p = p.get_parent()
		_network_cache = p as GNNetwork
	if _network_cache == null:
		return null
	var target: GNNode = _network_cache.get_node_by_id(target_id)
	if target == null or target.family != SDF_FAMILY:
		return null
	return target.cached_output
