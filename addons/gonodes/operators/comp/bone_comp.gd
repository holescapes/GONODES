class_name BoneCOMP
extends GNCompBase
## Attaches a COMP to a named bone in a Skeleton3D.
##
## Finds the skeleton from the upstream COMP's scene node hierarchy,
## creates a BoneAttachment3D for the named bone, and parents the
## source COMP's geometry to it. The attached node follows the bone
## transform automatically.
##
## Uses Godot's native BoneAttachment3D + Skeleton3D.

var _attachment: BoneAttachment3D = null
var _last_bone_name: String = ""


func _init() -> void:
	node_type = "bone"


func _init_ports() -> void:
	add_input("skeleton_in", GNFamily.Type.COMP, true, "COMP with Skeleton3D (e.g. from FileInSOP glTF)", "Skeleton")
	add_input("attach_in", GNFamily.Type.COMP, false, "COMP to attach to the bone", "Attach")
	add_output("out", GNFamily.Type.COMP, "Bone-attached component")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("bone_name", "Head",
		"Bone Name", "Name of the bone to attach to (case-sensitive)"))
	# Offset from bone
	add_parameter(GNParameter.create_float("ox", 0.0, null, null, 0.01, "Offset X", "Position offset from bone"))
	add_parameter(GNParameter.create_float("oy", 0.0, null, null, 0.01, "Offset Y", "Position offset from bone"))
	add_parameter(GNParameter.create_float("oz", 0.0, null, null, 0.01, "Offset Z", "Position offset from bone"))
	add_parameter(GNParameter.create_float("rx", 0.0, null, null, 0.1, "Rotate X", "Rotation offset (degrees)"))
	add_parameter(GNParameter.create_float("ry", 0.0, null, null, 0.1, "Rotate Y", "Rotation offset (degrees)"))
	add_parameter(GNParameter.create_float("rz", 0.0, null, null, 0.1, "Rotate Z", "Rotation offset (degrees)"))
	add_parameter(GNParameter.create_bool("override_pose", false,
		"Override Pose", "If true, write back offset as bone pose override"))
	add_parameter(GNParameter.create_bool("use_external_skeleton", false,
		"Use External Skeleton", "Use external skeleton path instead of walking upstream"))


func _cook(inputs: Array[GNData]) -> GNData:
	var skeleton_data = inputs[0] if inputs.size() > 0 else null
	var attach_data = inputs[1] if inputs.size() > 1 else null

	if skeleton_data == null:
		node_warning = "No skeleton COMP connected"
		return null

	# Find skeleton from upstream
	var skeleton_node: Node3D = _get_upstream_scene_node(0)
	var skeleton: Skeleton3D = _find_skeleton(skeleton_node)

	if skeleton == null:
		node_warning = "No Skeleton3D found in upstream scene"
		return skeleton_data

	var bone_name: String = get_param_value("bone_name")
	var bone_idx := skeleton.find_bone(bone_name)
	if bone_idx < 0:
		node_warning = "Bone '%s' not found. Available: %s" % [bone_name, _list_bones(skeleton)]
		return skeleton_data

	node_warning = ""

	# Create or update BoneAttachment3D
	if _attachment == null or bone_name != _last_bone_name:
		_cleanup_attachment()
		_attachment = BoneAttachment3D.new()
		_attachment.name = id + "_bone_attach"
		_attachment.bone_name = bone_name
		skeleton.add_child(_attachment)
		_last_bone_name = bone_name

	# Apply offset
	var offset_pos := Vector3(get_param_value("ox"), get_param_value("oy"), get_param_value("oz"))
	var offset_rot := Vector3(get_param_value("rx"), get_param_value("ry"), get_param_value("rz"))
	_attachment.position = offset_pos
	_attachment.rotation_degrees = offset_rot

	# If attach input is provided, reparent its scene node under the attachment
	if attach_data != null:
		var attach_node: Node3D = _get_upstream_scene_node(1)
		if attach_node != null and attach_node.get_parent() != _attachment:
			if attach_node.get_parent() != null:
				attach_node.get_parent().remove_child(attach_node)
			_attachment.add_child(attach_node)

	# Override pose if requested
	if get_param_value("override_pose"):
		skeleton.set_bone_pose_position(bone_idx, offset_pos)
		skeleton.set_bone_pose_rotation(bone_idx,
			Quaternion.from_euler(Vector3(
				deg_to_rad(offset_rot.x),
				deg_to_rad(offset_rot.y),
				deg_to_rad(offset_rot.z))))

	_scene_node = skeleton_node
	return skeleton_data


func _get_upstream_scene_node(port: int) -> Node3D:
	var upstream := get_input_node(port)
	if upstream != null and upstream is GNCompBase:
		return (upstream as GNCompBase).get_scene_node()
	return null


func _find_skeleton(node: Node3D) -> Skeleton3D:
	if node == null:
		return null
	if node is Skeleton3D:
		return node as Skeleton3D
	# Search children recursively (glTF imports nest Skeleton3D)
	for child in node.get_children():
		if child is Skeleton3D:
			return child as Skeleton3D
		if child is Node3D:
			var found := _find_skeleton(child as Node3D)
			if found != null:
				return found
	return null


func _list_bones(skeleton: Skeleton3D) -> String:
	var names: PackedStringArray = []
	for i in range(mini(skeleton.get_bone_count(), 10)):
		names.append(skeleton.get_bone_name(i))
	if skeleton.get_bone_count() > 10:
		names.append("... (%d total)" % skeleton.get_bone_count())
	return ", ".join(names)


func _cleanup_attachment() -> void:
	if _attachment != null and is_instance_valid(_attachment):
		if _attachment.get_parent() != null:
			_attachment.get_parent().remove_child(_attachment)
		_attachment.queue_free()
		_attachment = null


func _on_node_removed() -> void:
	_cleanup_attachment()
