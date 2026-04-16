class_name PhysicsCHOP
extends GNChopBase
## Reads transform, velocity, and physics state from an upstream physics COMP.
##
## Outputs named channels for position (tx, ty, tz), rotation in degrees
## (rx, ry, rz), scale (sx, sy, sz), linear velocity (vel_x, vel_y, vel_z),
## angular velocity (ang_vel_x, ang_vel_y, ang_vel_z), speed, and sleeping state.
##
## Architecture:
##   RigidBodyCOMP (or any physics COMP) → PhysicsCHOP → downstream CHOPs
##
## This operator uses network walking to find the upstream COMP node and read
## its scene node's current physics state.  No data flows through the input
## port — only the node reference matters.


func _init() -> void:
	node_type = "physics"


func _init_ports() -> void:
	add_input("comp_in", GNFamily.Type.COMP, false, "Physics body COMP input", "Comp")
	add_output("out", GNFamily.Type.CHOP, "Physics readback channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("position", true,
		"Position", "Output tx, ty, tz channels"))
	add_parameter(GNParameter.create_bool("rotation", true,
		"Rotation", "Output rx, ry, rz channels (degrees)"))
	add_parameter(GNParameter.create_bool("scale", false,
		"Scale", "Output sx, sy, sz channels"))
	add_parameter(GNParameter.create_bool("linear_vel", true,
		"Linear Velocity", "Output vel_x, vel_y, vel_z channels"))
	add_parameter(GNParameter.create_bool("angular_vel", false,
		"Angular Velocity", "Output ang_vel_x, ang_vel_y, ang_vel_z channels"))
	add_parameter(GNParameter.create_bool("speed", false,
		"Speed", "Output speed channel (magnitude of linear velocity)"))
	add_parameter(GNParameter.create_bool("sleeping", false,
		"Sleeping", "Output sleeping channel (1.0 = sleeping, 0.0 = awake)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var comp_data := _inputs[0] as GNCompData if _inputs.size() > 0 else null
	if comp_data == null or comp_data.scene_node == null:
		return _prepare_output()  # Empty channel data

	var scene_node: Node3D = comp_data.scene_node

	var out: GNChannelData = _prepare_output()

	# ── Position ─────────────────────────────────────────────────────────
	if get_param_value("position"):
		var pos: Vector3 = scene_node.global_position if scene_node.is_inside_tree() else scene_node.position
		out.set_single_value("tx", pos.x)
		out.set_single_value("ty", pos.y)
		out.set_single_value("tz", pos.z)

	# ── Rotation (degrees) ───────────────────────────────────────────────
	if get_param_value("rotation"):
		var rot: Vector3 = scene_node.global_rotation_degrees if scene_node.is_inside_tree() else scene_node.rotation_degrees
		out.set_single_value("rx", rot.x)
		out.set_single_value("ry", rot.y)
		out.set_single_value("rz", rot.z)

	# ── Scale ────────────────────────────────────────────────────────────
	if get_param_value("scale"):
		var scl: Vector3 = scene_node.scale
		out.set_single_value("sx", scl.x)
		out.set_single_value("sy", scl.y)
		out.set_single_value("sz", scl.z)

	# ── Linear Velocity ──────────────────────────────────────────────────
	var lin_vel := Vector3.ZERO
	var has_rigid: bool = scene_node is RigidBody3D
	if has_rigid:
		lin_vel = (scene_node as RigidBody3D).linear_velocity

	if get_param_value("linear_vel"):
		out.set_single_value("vel_x", lin_vel.x)
		out.set_single_value("vel_y", lin_vel.y)
		out.set_single_value("vel_z", lin_vel.z)

	# ── Angular Velocity ─────────────────────────────────────────────────
	if get_param_value("angular_vel"):
		var ang_vel := Vector3.ZERO
		if has_rigid:
			ang_vel = (scene_node as RigidBody3D).angular_velocity
		out.set_single_value("ang_vel_x", ang_vel.x)
		out.set_single_value("ang_vel_y", ang_vel.y)
		out.set_single_value("ang_vel_z", ang_vel.z)

	# ── Speed (scalar) ───────────────────────────────────────────────────
	if get_param_value("speed"):
		out.set_single_value("speed", lin_vel.length())

	# ── Sleeping ─────────────────────────────────────────────────────────
	if get_param_value("sleeping"):
		var asleep: float = 0.0
		if has_rigid:
			asleep = 1.0 if (scene_node as RigidBody3D).sleeping else 0.0
		out.set_single_value("sleeping", asleep)

	return out
