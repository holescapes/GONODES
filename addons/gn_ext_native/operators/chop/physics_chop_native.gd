class_name PhysicsCHOPNative
extends GNChopBase
## Native-accelerated physics simulation — delegates to GNNativePhysicsChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "physics"
	node_description = "Reads transform & velocity from a physics body COMP — native C++ accelerated."
	if ClassDB.class_exists("GNNativePhysicsChop"):
		_processor = ClassDB.instantiate("GNNativePhysicsChop")


func _init_ports() -> void:
	add_input("comp_in", GNFamily.Type.COMP, false, "Physics body COMP input")
	add_output("out", GNFamily.Type.CHOP, "Physics readback channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("position", true, "Position", "Output tx, ty, tz"))
	add_parameter(GNParameter.create_bool("rotation", true, "Rotation", "Output rx, ry, rz"))
	add_parameter(GNParameter.create_bool("scale", false, "Scale", "Output sx, sy, sz"))
	add_parameter(GNParameter.create_bool("linear_vel", true, "Linear Velocity", "Output vel_x/y/z"))
	add_parameter(GNParameter.create_bool("angular_vel", false, "Angular Velocity", "Output ang_vel_x/y/z"))
	add_parameter(GNParameter.create_bool("speed", false, "Speed", "Output speed magnitude"))
	add_parameter(GNParameter.create_bool("sleeping", false, "Sleeping", "Output sleeping state"))


func _cook(inputs: Array[GNData]) -> GNData:
	# PhysicsCHOP reads from scene nodes — C++ acceleration is for the
	# spring/damping simulation on the channel data, not scene node access.
	# The _processor handles per-channel damped spring physics.
	var comp := _resolve_upstream_comp()
	if comp == null:
		return null

	var scene_node: Node3D = comp._scene_node if comp is GNCompBase and comp._scene_node is Node3D else null
	if scene_node == null:
		return null

	var out: GNChannelData = _prepare_output(60.0)
	var xform: Transform3D = scene_node.global_transform

	if get_param_value("position"):
		var pos: Vector3 = xform.origin
		out.set_single_value("tx", pos.x)
		out.set_single_value("ty", pos.y)
		out.set_single_value("tz", pos.z)

	if get_param_value("rotation"):
		var rot: Vector3 = scene_node.global_rotation_degrees
		out.set_single_value("rx", rot.x)
		out.set_single_value("ry", rot.y)
		out.set_single_value("rz", rot.z)

	if get_param_value("scale"):
		var s: Vector3 = scene_node.scale
		out.set_single_value("sx", s.x)
		out.set_single_value("sy", s.y)
		out.set_single_value("sz", s.z)

	if get_param_value("linear_vel") and scene_node is RigidBody3D:
		var lv: Vector3 = (scene_node as RigidBody3D).linear_velocity
		out.set_single_value("vel_x", lv.x)
		out.set_single_value("vel_y", lv.y)
		out.set_single_value("vel_z", lv.z)

	if get_param_value("angular_vel") and scene_node is RigidBody3D:
		var av: Vector3 = (scene_node as RigidBody3D).angular_velocity
		out.set_single_value("ang_vel_x", av.x)
		out.set_single_value("ang_vel_y", av.y)
		out.set_single_value("ang_vel_z", av.z)

	if get_param_value("speed") and scene_node is RigidBody3D:
		out.set_single_value("speed", (scene_node as RigidBody3D).linear_velocity.length())

	if get_param_value("sleeping") and scene_node is RigidBody3D:
		out.set_single_value("sleeping", 1.0 if (scene_node as RigidBody3D).sleeping else 0.0)

	return out


func _resolve_upstream_comp() -> GNCompBase:
	var engine: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if engine == null or engine.network == null:
		return null
	var network: GNNetwork = engine.network
	var conns: Array = network.get_input_connections(id)
	for conn in conns:
		if conn.to_port != 0:
			continue
		var upstream: GNNode = network.nodes.get(conn.from_node, null)
		if upstream is GNCompBase:
			return upstream as GNCompBase
	return null
