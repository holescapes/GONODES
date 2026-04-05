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

	# Resolve the owning GNNetwork (cached for performance)
	if _network_cache == null or not is_instance_valid(_network_cache):
		var p = get_parent()
		while p != null and not (p is GNNetwork):
			p = p.get_parent()
		_network_cache = p as GNNetwork

	if _network_cache == null:
		GNLogger.warn("SelectTOP", "'%s' — could not find parent GNNetwork" % id)
		return null

	var target: GNNode = _network_cache.get_node_by_id(target_id)
	if target == null:
		node_warning = "Target '%s' not found" % target_id
		GNLogger.warn("SelectTOP", "'%s' — target '%s' not found" % [id, target_id])
		return null

	if target.family != GNFamily.Type.TOP:
		node_warning = "Target '%s' is not a TOP" % target_id
		GNLogger.warn("SelectTOP", "'%s' — target '%s' is %s, not TOP" % [id, target_id, GNFamily.FAMILY_NAMES.get(target.family, "UNKNOWN")])
		return null

	node_warning = ""

	# Return the target's cached output directly — zero copy
	var tex_data: GNTextureData = target.cached_output as GNTextureData if target.cached_output is GNTextureData else null
	if tex_data == null or tex_data.texture == null:
		return null

	return tex_data
