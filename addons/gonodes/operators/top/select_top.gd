class_name SelectTOP
extends GNTopBase
## References a remote TOP node by name — outputs that node's texture
## without requiring a wire connection.
##
## Equivalent to TouchDesigner's Select TOP.  Essential for complex networks
## where wiring every reference would create spaghetti.
##
## The referenced node must be a TOP family operator in the same network.
## If the target is not found or has no output, this TOP outputs nothing.

var _network_cache: GNNetwork = null


func _init() -> void:
	node_type = "select"


func _init_ports() -> void:
	# No inputs — references by name instead of wire
	add_output("out", GNFamily.Type.TOP, "Texture from the referenced TOP")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("top", GNFamily.Type.TOP,
		"TOP", "Name (id) of the TOP node to reference"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var target_id: String = get_param_value("top")
	if target_id.is_empty():
		node_warning = "No target TOP specified"
		return null

	# Resolve the owning GNNetwork via the CookEngine parent
	if _network_cache == null or not is_instance_valid(_network_cache):
		var p = get_parent()
		if p is GNCookEngine:
			_network_cache = p.network
		else:
			# Fallback: walk parents for a CookEngine
			while p != null:
				if p is GNCookEngine:
					_network_cache = p.network
					break
				p = p.get_parent()

	if _network_cache == null:
		GNLogger.warn("SelectTOP", "'%s' — could not find parent GNNetwork" % id)
		return null

	var target: GNNode = _network_cache.get_node_by_id(target_id)
	if target == null:
		node_warning = "Target '%s' not found" % target_id
		GNLogger.warn("SelectTOP", "'%s' — target '%s' not found" % [id, target_id])
		return null

	# Check data type, not node family — SubNetworkNode/GNCustomOperator can output valid TOP data
	var tex_data: GNTextureData = target.cached_output as GNTextureData if target.cached_output is GNTextureData else null
	if tex_data == null or tex_data.texture == null:
		node_warning = "Target '%s' does not output texture data" % target_id
		return null

	node_warning = ""
	return tex_data
