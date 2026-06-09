class_name SelectIMG
extends GNImgBase
## Wireless reference — outputs a named remote IMG node's image data.
##
## The 'img' parameter holds the node id of the source IMG.
## Rule: only Select nodes do wireless referencing — no wire input.

var _network_cache: GNNetwork = null


func _init() -> void:
	node_type = "select"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.IMG, "Selected image", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("img", GNFamily.Type.IMG,
		"IMG", "Node id of the remote IMG to reference"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var remote_id: String = get_param_value("img")
	if remote_id.is_empty():
		node_warning = "No node reference specified"
		return null
	var data: GNData = _resolve_remote(remote_id, GNFamily.Type.IMG)
	if data is GNImageData:
		node_warning = ""
		return data
	node_warning = "Remote IMG '%s' not found or has no output" % remote_id
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
