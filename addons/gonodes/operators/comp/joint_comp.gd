class_name JointCOMP
extends GNCompBase
## Wraps Godot Joint3D subtypes to constrain two physics bodies together.
##
## Supports: Hinge, Slider, Pin, ConeTwist, and Generic 6DOF joints.
## Takes two COMP inputs (Body A and Body B) and creates a physical constraint
## between them.
##
## Architecture:
##   RigidBodyCOMP A ──┐
##                     ├── JointCOMP → MergeCOMP → RenderTOP
##   RigidBodyCOMP B ──┘

var _joint: Joint3D = null
var _current_joint_type: int = -1


func _init() -> void:
	node_type = "joint"


func _init_ports() -> void:
	add_input("body_a", GNFamily.Type.COMP, false, "First physics body (COMP)", "Body A")
	add_input("body_b", GNFamily.Type.COMP, false, "Second physics body (COMP)", "Body B")
	add_output("out", GNFamily.Type.COMP, "Joint component")


func _init_parameters() -> void:
	# ── Transform (joint anchor point) ───────────────────────────────────
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", "Joint anchor X"))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01, "Translate Y", "Joint anchor Y"))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01, "Translate Z", "Joint anchor Z"))
	add_parameter(GNParameter.create_float("rx", 0.0, null, null, 0.1, "Rotate X", "Joint axis rotation X"))
	add_parameter(GNParameter.create_float("ry", 0.0, null, null, 0.1, "Rotate Y", "Joint axis rotation Y"))
	add_parameter(GNParameter.create_float("rz", 0.0, null, null, 0.1, "Rotate Z", "Joint axis rotation Z"))

	# ── Joint Type ───────────────────────────────────────────────────────
	add_parameter(GNParameter.create_enum("joint_type",
		PackedStringArray(["Pin", "Hinge", "Slider", "Cone Twist", "6DOF"]), 0,
		"Joint Type", "Type of physical constraint"))

	# ── Collision ────────────────────────────────────────────────────────
	add_parameter(GNParameter.create_bool("exclude_collision", true,
		"Exclude Collision", "Disable collision between connected bodies"))

	# ── Hinge params ─────────────────────────────────────────────────────
	add_parameter(GNParameter.create_bool("hinge_limit", false,
		"Hinge Limit", "Enable angular limits for hinge joint"))
	add_parameter(GNParameter.create_float("hinge_lower", -90.0, -180.0, 0.0, 1.0,
		"Hinge Lower", "Lower angle limit (degrees)"))
	add_parameter(GNParameter.create_float("hinge_upper", 90.0, 0.0, 180.0, 1.0,
		"Hinge Upper", "Upper angle limit (degrees)"))
	add_parameter(GNParameter.create_bool("hinge_motor", false,
		"Hinge Motor", "Enable motor to drive the hinge"))
	add_parameter(GNParameter.create_float("hinge_motor_speed", 1.0, -100.0, 100.0, 0.1,
		"Motor Speed", "Target angular velocity (rad/s)"))
	add_parameter(GNParameter.create_float("hinge_motor_force", 10.0, 0.0, 1000.0, 0.5,
		"Motor Force", "Maximum motor impulse"))

	# ── Slider params ────────────────────────────────────────────────────
	add_parameter(GNParameter.create_float("slider_lower", -1.0, -100.0, 0.0, 0.1,
		"Slider Lower", "Lower linear limit"))
	add_parameter(GNParameter.create_float("slider_upper", 1.0, 0.0, 100.0, 0.1,
		"Slider Upper", "Upper linear limit"))

	# ── Cone Twist params ────────────────────────────────────────────────
	add_parameter(GNParameter.create_float("cone_swing", 45.0, 0.0, 180.0, 1.0,
		"Swing Span", "Maximum swing angle (degrees)"))
	add_parameter(GNParameter.create_float("cone_twist", 45.0, 0.0, 180.0, 1.0,
		"Twist Span", "Maximum twist angle (degrees)"))
	add_parameter(GNParameter.create_float("cone_softness", 0.8, 0.0, 1.0, 0.01,
		"Softness", "Constraint softness"))
	add_parameter(GNParameter.create_float("cone_relaxation", 1.0, 0.0, 1.0, 0.01,
		"Relaxation", "Relaxation factor"))

	# ── 6DOF params ──────────────────────────────────────────────────────
	add_parameter(GNParameter.create_bool("dof_lock_lin_x", false, "Lock Linear X", "Lock linear X axis"))
	add_parameter(GNParameter.create_bool("dof_lock_lin_y", false, "Lock Linear Y", "Lock linear Y axis"))
	add_parameter(GNParameter.create_bool("dof_lock_lin_z", false, "Lock Linear Z", "Lock linear Z axis"))
	add_parameter(GNParameter.create_bool("dof_lock_ang_x", false, "Lock Angular X", "Lock angular X axis"))
	add_parameter(GNParameter.create_bool("dof_lock_ang_y", false, "Lock Angular Y", "Lock angular Y axis"))
	add_parameter(GNParameter.create_bool("dof_lock_ang_z", false, "Lock Angular Z", "Lock angular Z axis"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var joint_type: int = get_param_value("joint_type")

	# Recreate joint if type changed
	if joint_type != _current_joint_type:
		_create_joint(joint_type)
		_current_joint_type = joint_type

	if _joint == null:
		return null

	# ── Transform ────────────────────────────────────────────────────────
	_joint.position = Vector3(
		get_param_value("tx"), get_param_value("ty"), get_param_value("tz"))
	_joint.rotation_degrees = Vector3(
		get_param_value("rx"), get_param_value("ry"), get_param_value("rz"))

	_joint.exclude_nodes_from_collision = get_param_value("exclude_collision")

	# ── Connect bodies via network walk ──────────────────────────────────
	_connect_bodies()

	# ── Apply type-specific params ───────────────────────────────────────
	match joint_type:
		1: _apply_hinge_params()
		2: _apply_slider_params()
		3: _apply_cone_twist_params()
		4: _apply_6dof_params()

	return _build_comp_data()


func _create_joint(joint_type: int) -> void:
	# Free old joint
	if _joint != null:
		if _joint.get_parent() != null:
			_joint.get_parent().remove_child(_joint)
		_joint.queue_free()
		_joint = null

	match joint_type:
		0: _joint = PinJoint3D.new()
		1: _joint = HingeJoint3D.new()
		2: _joint = SliderJoint3D.new()
		3: _joint = ConeTwistJoint3D.new()
		4: _joint = Generic6DOFJoint3D.new()

	if _joint != null:
		_joint.name = id + "_joint"
		_scene_node = _joint


## Destroys the scene node and resets joint state so the
## next cook recreates the Joint3D from scratch.
func destroy_scene_node() -> void:
	super.destroy_scene_node()
	_joint = null
	_current_joint_type = -1


## Reads Body A and Body B scene nodes from upstream data and sets their NodePaths.
func _connect_bodies() -> void:
	if _joint == null:
		return

	var body_a_node: Node3D = _get_upstream_scene_node(0)
	var body_b_node: Node3D = _get_upstream_scene_node(1)

	# Set node paths relative to the joint
	if body_a_node != null and _joint.is_inside_tree() and body_a_node.is_inside_tree():
		_joint.node_a = _joint.get_path_to(body_a_node)
	else:
		_joint.node_a = NodePath("")

	if body_b_node != null and _joint.is_inside_tree() and body_b_node.is_inside_tree():
		_joint.node_b = _joint.get_path_to(body_b_node)
	else:
		_joint.node_b = NodePath("")


func _apply_hinge_params() -> void:
	var hinge := _joint as HingeJoint3D
	if hinge == null:
		return

	# Angular limit
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, get_param_value("hinge_limit"))
	if get_param_value("hinge_limit"):
		hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(get_param_value("hinge_lower")))
		hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(get_param_value("hinge_upper")))

	# Motor
	hinge.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, get_param_value("hinge_motor"))
	if get_param_value("hinge_motor"):
		hinge.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, get_param_value("hinge_motor_speed"))
		hinge.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, get_param_value("hinge_motor_force"))


func _apply_slider_params() -> void:
	var slider := _joint as SliderJoint3D
	if slider == null:
		return
	slider.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_LOWER, get_param_value("slider_lower"))
	slider.set_param(SliderJoint3D.PARAM_LINEAR_LIMIT_UPPER, get_param_value("slider_upper"))


func _apply_cone_twist_params() -> void:
	var cone := _joint as ConeTwistJoint3D
	if cone == null:
		return
	cone.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(get_param_value("cone_swing")))
	cone.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(get_param_value("cone_twist")))
	cone.set_param(ConeTwistJoint3D.PARAM_SOFTNESS, get_param_value("cone_softness"))
	cone.set_param(ConeTwistJoint3D.PARAM_RELAXATION, get_param_value("cone_relaxation"))


func _apply_6dof_params() -> void:
	var dof := _joint as Generic6DOFJoint3D
	if dof == null:
		return

	# Lock linear axes
	if get_param_value("dof_lock_lin_x"):
		dof.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
		dof.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
	if get_param_value("dof_lock_lin_y"):
		dof.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
		dof.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
	if get_param_value("dof_lock_lin_z"):
		dof.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
		dof.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)

	# Lock angular axes
	if get_param_value("dof_lock_ang_x"):
		dof.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 0.0)
		dof.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)
	if get_param_value("dof_lock_ang_y"):
		dof.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 0.0)
		dof.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)
	if get_param_value("dof_lock_ang_z"):
		dof.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 0.0)
		dof.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)
