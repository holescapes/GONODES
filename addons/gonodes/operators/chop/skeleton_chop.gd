class_name SkeletonCHOP
extends GNChopBase
## Reads skeleton/bone transforms from a Skeleton3D COMP as CHOP channels.
##
## For each bone, outputs channels: bone_name:tx, bone_name:ty, bone_name:tz,
## bone_name:rx, bone_name:ry, bone_name:rz.
## A bone filter parameter allows selecting specific bones by pattern.
##
## TouchDesigner equivalent: Skeleton CHOP / Pose CHOP.


func _init() -> void:
	node_type = "skeleton"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Bone transform channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("comp_path", GNFamily.Type.COMP,
		"COMP Path", "Node ID of the Skeleton3D COMP"))
	add_parameter(GNParameter.create_string("bone_filter", "*",
		"Bone Filter", "Wildcard pattern for bone names (* = all)"))
	add_parameter(GNParameter.create_bool("local", true,
		"Local Space", "Use bone-local transforms (false = model space)"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var comp_path: String = get_param_value("comp_path")
	if comp_path.is_empty():
		return null

	var ref_node: GNNode = _resolve_node_ref(comp_path)
	if ref_node == null:
		return null

	# Find the Skeleton3D from the COMP's scene node
	var skeleton: Skeleton3D = _find_skeleton(ref_node)
	if skeleton == null:
		return null

	var bone_filter: String = get_param_value("bone_filter")
	var use_local: bool = get_param_value("local")
	var out := _prepare_output(60.0)

	for bone_idx in range(skeleton.get_bone_count()):
		var bone_name: String = skeleton.get_bone_name(bone_idx)
		if not _matches_filter(bone_name, bone_filter):
			continue

		var xform: Transform3D
		if use_local:
			xform = skeleton.get_bone_pose(bone_idx)
		else:
			xform = skeleton.get_bone_global_pose(bone_idx)

		var pos := xform.origin
		var euler := xform.basis.get_euler()
		out.set_single_value("%s:tx" % bone_name, pos.x)
		out.set_single_value("%s:ty" % bone_name, pos.y)
		out.set_single_value("%s:tz" % bone_name, pos.z)
		out.set_single_value("%s:rx" % bone_name, rad_to_deg(euler.x))
		out.set_single_value("%s:ry" % bone_name, rad_to_deg(euler.y))
		out.set_single_value("%s:rz" % bone_name, rad_to_deg(euler.z))

	return out


func _resolve_node_ref(path: String) -> GNNode:
	var eng: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if eng == null or eng.network == null:
		return null
	return eng.network.nodes.get(path, null)


func _find_skeleton(node: GNNode) -> Skeleton3D:
	# Check if the node has a scene_node with a Skeleton3D
	if node.has_method("get_scene_node"):
		var sn = node.get_scene_node()
		if sn is Skeleton3D:
			return sn
		# Search children
		if sn != null:
			for child in sn.get_children():
				if child is Skeleton3D:
					return child
	return null


func _matches_filter(name: String, pattern: String) -> bool:
	if pattern == "*" or pattern.is_empty():
		return true
	return name.matchn(pattern)
