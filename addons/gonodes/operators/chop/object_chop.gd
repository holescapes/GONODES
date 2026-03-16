class_name ObjectCHOP
extends GNChopBase
## Reads transform channels (tx, ty, tz, rx, ry, rz, sx, sy, sz) from a
## COMP node referenced by path expression.
##
## This is the GONODES equivalent of TouchDesigner's Object CHOP — the
## primary way to read a scene object's transform into channel data for
## procedural animation, instancing, or UI display.


func _init() -> void:
	node_type = "object"
	time_dependent = true
	node_description = "Read COMP transform as CHOP channels."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Transform channels (tx/ty/tz/rx/ry/rz/sx/sy/sz)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("comp_path", "",
		"COMP Path", "Node ID of the COMP to read (e.g. camera1, geo1)"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var comp_path: String = get_param_value("comp_path")
	if comp_path.is_empty():
		return null

	# Look up the referenced COMP in the network
	var ref_node: GNNode = _resolve_node_ref(comp_path)
	if ref_node == null:
		return null

	var out := _prepare_output(60.0)

	# Try to extract transform from the COMP's scene node
	var xform := Transform3D.IDENTITY
	if ref_node.has_method("get_scene_transform"):
		xform = ref_node.get_scene_transform()
	elif ref_node.cached_output != null and ref_node.cached_output.has_method("get_transform"):
		xform = ref_node.cached_output.get_transform()
	else:
		# Fall back to reading tx/ty/tz/rx/ry/rz/sx/sy/sz parameters
		var tx := _read_param_float(ref_node, "tx")
		var ty := _read_param_float(ref_node, "ty")
		var tz := _read_param_float(ref_node, "tz")
		var rx := _read_param_float(ref_node, "rx")
		var ry := _read_param_float(ref_node, "ry")
		var rz := _read_param_float(ref_node, "rz")
		var sx := _read_param_float(ref_node, "sx", 1.0)
		var sy := _read_param_float(ref_node, "sy", 1.0)
		var sz := _read_param_float(ref_node, "sz", 1.0)
		out.set_single_value("tx", tx)
		out.set_single_value("ty", ty)
		out.set_single_value("tz", tz)
		out.set_single_value("rx", rx)
		out.set_single_value("ry", ry)
		out.set_single_value("rz", rz)
		out.set_single_value("sx", sx)
		out.set_single_value("sy", sy)
		out.set_single_value("sz", sz)
		return out

	# Decompose Transform3D
	var origin := xform.origin
	var basis := xform.basis
	var euler := basis.get_euler()
	var scale := basis.get_scale()
	out.set_single_value("tx", origin.x)
	out.set_single_value("ty", origin.y)
	out.set_single_value("tz", origin.z)
	out.set_single_value("rx", rad_to_deg(euler.x))
	out.set_single_value("ry", rad_to_deg(euler.y))
	out.set_single_value("rz", rad_to_deg(euler.z))
	out.set_single_value("sx", scale.x)
	out.set_single_value("sy", scale.y)
	out.set_single_value("sz", scale.z)

	return out


func _resolve_node_ref(path: String) -> GNNode:
	var eng: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if eng == null or eng.network == null:
		return null
	return eng.network.nodes.get(path, null)


func _read_param_float(node: GNNode, param_name: String, fallback: float = 0.0) -> float:
	if node.parameters.has(param_name):
		return float(node.get_param_value(param_name))
	return fallback
