class_name SelectIMG
extends GNImgBase
## References a remote IMG node by name — outputs that node's image
## without requiring a wire connection.
##
## When the 'img' parameter names a remote IMG, its output is used.
## When 'img' is empty, the wired input is used instead (pass-through).

var _network_cache: GNNetwork = null


func _init() -> void:
	node_type = "select"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "Input image (used when 'img' is empty)")
	add_output("out", GNFamily.Type.IMG, "Selected image")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("img", GNFamily.Type.IMG,
		"IMG", "Name (id) of a remote IMG to reference (empty = use wired input)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var remote_id: String = get_param_value("img")

	if not remote_id.is_empty():
		var data: GNData = _resolve_remote(remote_id, GNFamily.Type.IMG)
		if data is GNImageData:
			node_warning = ""
			return data
		node_warning = "Remote IMG '%s' not found or has no output" % remote_id
		return null

	node_warning = ""
	if inputs.size() > 0 and inputs[0] is GNImageData:
		return inputs[0]
	return null


func _resolve_remote(target_id: String, expected_family: int) -> GNData:
	if _network_cache == null or not is_instance_valid(_network_cache):
		var p = get_parent()
		while p != null and not (p is GNNetwork):
			p = p.get_parent()
		_network_cache = p as GNNetwork
	if _network_cache == null:
		return null
	var target: GNNode = _network_cache.get_node_by_id(target_id)
	if target == null or target.family != expected_family:
		return null
	return target.cached_output
