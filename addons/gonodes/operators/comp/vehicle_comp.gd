class_name VehicleCOMP
extends GNCompBase
## Vehicle physics body with wheels, suspension, and steering.
##
## Wraps Godot's VehicleBody3D + VehicleWheel3D for arcade or simulation
## vehicle physics. Takes a COMP input for the vehicle body mesh and
## automatically creates 4 wheels with configurable suspension.
##
## Architecture:
##   SOP → GeometryCOMP → VehicleCOMP → MergeCOMP → RenderTOP
##                           ↑
##                       CHOP (controls)

var _vehicle: VehicleBody3D = null
var _collision_shape: CollisionShape3D = null
var _wheels: Array[VehicleWheel3D] = []
var _mesh_instance: MeshInstance3D = null
var _current_shape_type: int = -1


func _init() -> void:
	node_type = "vehicle"


func _init_ports() -> void:
	add_input("comp_in", GNFamily.Type.COMP, false, "Body geometry COMP", "Body")
	add_input("control_in", GNFamily.Type.CHOP, false, "Control CHOP (steer, throttle, brake)", "Controls")
	add_output("out", GNFamily.Type.COMP, "Vehicle component")


func _init_parameters() -> void:
	# Transform (initial placement)
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.1, "Translate X", "Start X"))
	add_parameter(GNParameter.create_float("ty", 1.0, null, null, 0.1, "Translate Y", "Start Y (above ground)"))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.1, "Translate Z", "Start Z"))
	add_parameter(GNParameter.create_float("ry", 0.0, null, null, 1.0, "Rotate Y", "Start heading (degrees)"))

	# Body physics
	add_parameter(GNParameter.create_float("mass", 1200.0, 10.0, 10000.0, 10.0,
		"Mass", "Vehicle mass in kg"))

	# Wheel layout
	add_parameter(GNParameter.create_float("wheel_base", 2.4, 0.5, 10.0, 0.1,
		"Wheel Base", "Front-to-rear axle distance"))
	add_parameter(GNParameter.create_float("track_width", 1.6, 0.5, 6.0, 0.1,
		"Track Width", "Left-to-right wheel distance"))
	add_parameter(GNParameter.create_float("wheel_radius", 0.35, 0.1, 2.0, 0.01,
		"Wheel Radius", "Radius of each wheel"))

	# Suspension
	add_parameter(GNParameter.create_float("suspension_rest", 0.15, 0.0, 1.0, 0.01,
		"Suspension Rest", "Suspension rest length"))
	add_parameter(GNParameter.create_float("suspension_travel", 0.2, 0.01, 1.0, 0.01,
		"Suspension Travel", "Max suspension compression"))
	add_parameter(GNParameter.create_float("suspension_stiffness", 50.0, 1.0, 200.0, 1.0,
		"Suspension Stiffness", "Spring stiffness (N/m)"))
	add_parameter(GNParameter.create_float("damping", 4.0, 0.0, 50.0, 0.5,
		"Damping", "Shock absorber damping"))

	# Drive parameters (manual control when no CHOP)
	add_parameter(GNParameter.create_float("steer", 0.0, -1.0, 1.0, 0.01,
		"Steer", "Steering input (-1 = full left, 1 = full right)"))
	add_parameter(GNParameter.create_float("throttle", 0.0, -1.0, 1.0, 0.01,
		"Throttle", "Engine force (-1 = reverse, 1 = full forward)"))
	add_parameter(GNParameter.create_float("brake", 0.0, 0.0, 1.0, 0.01,
		"Brake", "Brake force (0 = none, 1 = full)"))

	# Tuning
	add_parameter(GNParameter.create_float("max_steer_angle", 30.0, 5.0, 60.0, 1.0,
		"Max Steer Angle", "Maximum steering angle (degrees)"))
	add_parameter(GNParameter.create_float("engine_force", 300.0, 0.0, 5000.0, 10.0,
		"Engine Force", "Maximum engine force"))
	add_parameter(GNParameter.create_float("brake_force", 50.0, 0.0, 500.0, 5.0,
		"Brake Force", "Maximum brake force"))
	add_parameter(GNParameter.create_enum("drive_type",
		PackedStringArray(["RWD", "FWD", "AWD"]), 2,
		"Drive Type", "Which wheels receive engine power"))


func _cook(inputs: Array[GNData]) -> GNData:
	var comp_data = inputs[0] if inputs.size() > 0 else null
	var chop_data: GNChannelData = inputs[1] as GNChannelData if inputs.size() > 1 and inputs[1] is GNChannelData else null

	_ensure_vehicle()

	# Adopt upstream mesh
	if comp_data != null:
		var upstream_node: Node3D = _get_upstream_scene_node(0)
		if upstream_node != null:
			_adopt_mesh_from_upstream(upstream_node)

	# Read controls from CHOP or params
	var steer_val: float = get_param_value("steer")
	var throttle_val: float = get_param_value("throttle")
	var brake_val: float = get_param_value("brake")

	if chop_data != null:
		steer_val = chop_data.get_channel_value("steer", steer_val)
		throttle_val = chop_data.get_channel_value("throttle", throttle_val)
		brake_val = chop_data.get_channel_value("brake", brake_val)

	# Apply controls
	var max_steer_rad := deg_to_rad(get_param_value("max_steer_angle"))
	var engine_f: float = get_param_value("engine_force")
	var brake_f: float = get_param_value("brake_force")
	var drive_type: int = get_param_value("drive_type")

	for i in range(_wheels.size()):
		var wheel := _wheels[i]
		var is_front := (i < 2)
		var is_rear := (i >= 2)

		# Steering — front wheels only
		if is_front:
			wheel.steering = steer_val * max_steer_rad

		# Engine power
		var apply_power := false
		match drive_type:
			0: apply_power = is_rear   # RWD
			1: apply_power = is_front  # FWD
			2: apply_power = true      # AWD
		wheel.engine_force = throttle_val * engine_f if apply_power else 0.0

		# Brakes — all wheels
		wheel.brake = brake_val * brake_f

	# Update suspension params
	_update_wheel_params()

	node_warning = ""
	return comp_data if comp_data != null else _build_comp_data()


func _ensure_vehicle() -> void:
	if _vehicle != null and is_instance_valid(_vehicle):
		return

	_vehicle = VehicleBody3D.new()
	_vehicle.name = id + "_vehicle"
	_vehicle.mass = get_param_value("mass")
	_vehicle.position = Vector3(
		get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))
	_vehicle.rotation_degrees = Vector3(0, get_param_value("ry"), 0)

	# Collision box
	_collision_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(get_param_value("track_width"), 0.5,
		get_param_value("wheel_base"))
	_collision_shape.shape = box
	_vehicle.add_child(_collision_shape)

	# Create 4 wheels:  FL, FR, RL, RR
	_create_wheels()

	_scene_node = _vehicle


func _create_wheels() -> void:
	_wheels.clear()
	var half_base: float = get_param_value("wheel_base") * 0.5
	var half_track: float = get_param_value("track_width") * 0.5
	var radius: float = get_param_value("wheel_radius")

	var positions: Array[Vector3] = [
		Vector3(-half_track, 0.0, half_base),   # FL
		Vector3(half_track, 0.0, half_base),    # FR
		Vector3(-half_track, 0.0, -half_base),  # RL
		Vector3(half_track, 0.0, -half_base),   # RR
	]
	var names := ["FL", "FR", "RL", "RR"]

	for i in range(4):
		var wheel := VehicleWheel3D.new()
		wheel.name = names[i]
		wheel.position = positions[i]
		wheel.wheel_radius = radius
		wheel.wheel_rest_length = get_param_value("suspension_rest")
		wheel.suspension_travel = get_param_value("suspension_travel")
		wheel.suspension_stiffness = get_param_value("suspension_stiffness")
		wheel.damping_compression = get_param_value("damping")
		wheel.damping_relaxation = get_param_value("damping") * 1.5
		_vehicle.add_child(wheel)
		_wheels.append(wheel)


func _update_wheel_params() -> void:
	var radius: float = get_param_value("wheel_radius")
	for wheel in _wheels:
		wheel.wheel_radius = radius
		wheel.wheel_rest_length = get_param_value("suspension_rest")
		wheel.suspension_travel = get_param_value("suspension_travel")
		wheel.suspension_stiffness = get_param_value("suspension_stiffness")
		wheel.damping_compression = get_param_value("damping")
		wheel.damping_relaxation = get_param_value("damping") * 1.5
	_vehicle.mass = get_param_value("mass")


func _adopt_mesh_from_upstream(upstream_node: Node3D) -> void:
	if upstream_node is MeshInstance3D:
		if _mesh_instance != upstream_node:
			if _mesh_instance != null and is_instance_valid(_mesh_instance):
				_mesh_instance.queue_free()
			_mesh_instance = upstream_node as MeshInstance3D
			if _mesh_instance.get_parent() != _vehicle:
				if _mesh_instance.get_parent() != null:
					_mesh_instance.get_parent().remove_child(_mesh_instance)
				_vehicle.add_child(_mesh_instance)


func _on_node_removed() -> void:
	_wheels.clear()
	if _vehicle != null and is_instance_valid(_vehicle):
		if _vehicle.get_parent() != null:
			_vehicle.get_parent().remove_child(_vehicle)
		_vehicle.queue_free()
		_vehicle = null
