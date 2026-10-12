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
## Target exists but has not produced a texture yet (feedback first frame).
var _output_pending: bool = false


func null_output_is_pending() -> bool:
	return _output_pending


func _init() -> void:
	node_type = "select"
	# No wire inputs — wireless refresh is engine-driven (demand map +
	# consumer dirty/hash when the target cooks, e.g. CacheTOP feedback).


func _init_ports() -> void:
	# No inputs — references by name instead of wire
	add_output("out", GNFamily.Type.TOP, "Texture from the referenced TOP")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("top", GNFamily.Type.TOP,
		"TOP", "Name (id) of the TOP node to reference"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_output_pending = false
	var target_id: String = get_param_value("top")
	if target_id.is_empty():
		node_warning = "No target TOP specified"
		return null

	# Resolve the owning GNNetwork via the CookEngine parent
	if _network_cache == null or not is_instance_valid(_network_cache):
		_network_cache = get_owning_network()

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
		# A CHOP (or anything that already cooked a non-texture) is a bad target.
		# A TOP that simply has not cooked yet is the feedback buffer's first frame.
		if target.cached_output != null and not (target.cached_output is GNTextureData):
			node_warning = "Target '%s' does not output texture data" % target_id
			return null
		_output_pending = true
		node_warning = ""
		return null

	node_warning = ""
	return tex_data
