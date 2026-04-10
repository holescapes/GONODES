class_name ConstraintCOMP
extends GNCompBase
## Constrains a COMP's transform to follow another COMP.
##
## Modes:
##   • Look At  — rotates to face the target COMP
##   • Parent   — copies the target's full transform (with offset)
##   • Path     — follows the target but blends with its own transform
##
## Uses Godot's native Node3D.look_at() and Transform3D math.

var _proxy: Node3D = null


func _init() -> void:
	node_type = "constraint"


func _init_ports() -> void:
	add_input("comp_in", GNFamily.Type.COMP, true, "Source COMP to constrain", "Source")
	add_input("target_in", GNFamily.Type.COMP, false, "Target COMP to follow", "Target")
	add_output("out", GNFamily.Type.COMP, "Constrained component")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Look At", "Parent", "Blend"]), 0,
		"Mode", "Constraint type"))
	add_parameter(GNParameter.create_float("blend", 1.0, 0.0, 1.0, 0.01,
		"Blend", "Constraint influence (0 = none, 1 = full)"))
	# Offset (applied after constraint)
	add_parameter(GNParameter.create_float("ox", 0.0, null, null, 0.01, "Offset X", "Position offset X"))
	add_parameter(GNParameter.create_float("oy", 0.0, null, null, 0.01, "Offset Y", "Position offset Y"))
	add_parameter(GNParameter.create_float("oz", 0.0, null, null, 0.01, "Offset Z", "Position offset Z"))
	# Look At options
	add_parameter(GNParameter.create_enum("up_axis",
		PackedStringArray(["Y", "X", "Z"]), 0,
		"Up Axis", "Up direction for Look At mode"))
	# Axes toggle for Parent/Blend
	add_parameter(GNParameter.create_bool("constrain_position", true,
		"Constrain Position", "Follow target position"))
	add_parameter(GNParameter.create_bool("constrain_rotation", true,
		"Constrain Rotation", "Follow target rotation"))
	add_parameter(GNParameter.create_bool("constrain_scale", false,
		"Constrain Scale", "Follow target scale"))


func _cook(inputs: Array[GNData]) -> GNData:
	var source_comp = inputs[0] if inputs.size() > 0 else null
	var target_comp = inputs[1] if inputs.size() > 1 else null

	if source_comp == null:
		node_warning = "No source COMP connected"
		return null

	# Get the source scene node from upstream COMP
	var source_node: Node3D = _get_comp_scene_node(source_comp)
	if source_node == null:
		node_warning = "Source has no scene node"
		return source_comp

	# If no target, pass through unchanged
	if target_comp == null:
		node_warning = "No target COMP connected — pass-through"
		return source_comp

	var target_node: Node3D = _get_comp_scene_node(target_comp)
	if target_node == null:
		node_warning = "Target has no scene node"
		return source_comp

	node_warning = ""
	var mode: int = get_param_value("mode")
	var blend_amount: float = get_param_value("blend")
	var offset := Vector3(get_param_value("ox"), get_param_value("oy"), get_param_value("oz"))

	var src_xform := source_node.global_transform
	var tgt_xform := target_node.global_transform

	match mode:
		0:  # Look At
			var up_idx: int = get_param_value("up_axis")
			var up := Vector3.UP
			match up_idx:
				1: up = Vector3.RIGHT
				2: up = Vector3.FORWARD
			var dir := (tgt_xform.origin - src_xform.origin).normalized()
			if dir.length_squared() > 0.0001:
				var look_basis := Basis.looking_at(dir, up)
				if blend_amount >= 0.999:
					source_node.global_transform = Transform3D(look_basis, src_xform.origin)
				else:
					var blended := src_xform.basis.slerp(look_basis, blend_amount)
					source_node.global_transform = Transform3D(blended, src_xform.origin)
			source_node.position += offset

		1:  # Parent (copy target transform)
			var constrain_pos: bool = get_param_value("constrain_position")
			var constrain_rot: bool = get_param_value("constrain_rotation")
			var constrain_scl: bool = get_param_value("constrain_scale")

			var new_origin := tgt_xform.origin if constrain_pos else src_xform.origin
			var new_basis: Basis
			if constrain_rot and constrain_scl:
				new_basis = tgt_xform.basis
			elif constrain_rot:
				new_basis = Basis(tgt_xform.basis.get_rotation_quaternion()).scaled(src_xform.basis.get_scale())
			elif constrain_scl:
				new_basis = Basis(src_xform.basis.get_rotation_quaternion()).scaled(tgt_xform.basis.get_scale())
			else:
				new_basis = src_xform.basis

			if blend_amount >= 0.999:
				source_node.global_transform = Transform3D(new_basis, new_origin + offset)
			else:
				var blended_origin := src_xform.origin.lerp(new_origin, blend_amount)
				var blended_basis := src_xform.basis.slerp(new_basis, blend_amount)
				source_node.global_transform = Transform3D(blended_basis, blended_origin + offset)

		2:  # Blend (weighted mix of source and target transforms)
			var blended_origin := src_xform.origin.lerp(tgt_xform.origin, blend_amount)
			var blended_basis := src_xform.basis.slerp(tgt_xform.basis, blend_amount)
			source_node.global_transform = Transform3D(blended_basis, blended_origin + offset)

	_scene_node = source_node
	return source_comp


## Walk upstream to find the scene node owned by a COMP.
func _get_comp_scene_node(data: GNData) -> Node3D:
	# The data flowing through COMP wires is the output of a GNCompBase,
	# which typically stores a reference to a scene node.  We look at the
	# producing node's _scene_node via the cook engine's owner tracking.
	var producing_node := _find_producing_comp_node(data)
	if producing_node != null and producing_node is GNCompBase:
		return (producing_node as GNCompBase).get_scene_node()
	return null


func _find_producing_comp_node(data: GNData) -> GNNode:
	if data == null:
		return null
	# Walk inputs to find upstream COMP
	for i in range(input_ports.size()):
		var upstream := get_input_node(i)
		if upstream != null and upstream is GNCompBase:
			if upstream.cached_output == data:
				return upstream
	return null
