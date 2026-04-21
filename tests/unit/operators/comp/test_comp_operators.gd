extends Node
## Correctness tests for COMP operators.
##
## COMPs manage scene nodes (Node3D). We test instantiation, parameter setup,
## and that scene nodes are created where applicable.

var _network: GNNetwork
var _engine: GNCookEngine


func before_each() -> void:
	_network = GNNetwork.new()
	_engine = GNCookEngine.new()
	_engine.network = _network
	_engine.cooking_enabled = false
	_engine.elapsed_time = 1.0
	_engine.frame_count = 60
	_engine.current_delta = 1.0 / 60.0
	add_child(_engine)


func after_each() -> void:
	if is_instance_valid(_engine):
		remove_child(_engine)
		_engine.queue_free()


func _make_node(node: GNNode, id: String) -> GNNode:
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	return node


func _cook_no_input(node: GNNode) -> GNData:
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, _engine.frame_count)
	return node.cached_output


func _cook_with(node: GNNode, inputs: Array[GNData]) -> GNData:
	node.execute_cook(inputs, _engine.frame_count)
	return node.cached_output


# ═══════════════════════════════════════════════════════════════════════════════
# GeometryCOMP
# ═══════════════════════════════════════════════════════════════════════════════

func test_geometry_comp_instantiate() -> void:
	var node := _make_node(GeometryCOMP.new(), "geo1")
	GNTestAssert.assert_eq(node.node_type, "geo", "node_type")

func test_geometry_comp_default_transforms() -> void:
	var node := _make_node(GeometryCOMP.new(), "geo1")
	GNTestAssert.assert_approx(node.get_param_value("tx"), 0.0, 0.001, "tx default")
	GNTestAssert.assert_approx(node.get_param_value("ty"), 0.0, 0.001, "ty default")
	GNTestAssert.assert_approx(node.get_param_value("tz"), 0.0, 0.001, "tz default")

func test_geometry_comp_produces_output() -> void:
	var node := _make_node(GeometryCOMP.new(), "geo1")
	# GeometryCOMP needs SOP input to display, but should not crash without it
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNData, "no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# CameraCOMP
# ═══════════════════════════════════════════════════════════════════════════════

func test_camera_comp_instantiate() -> void:
	var node := _make_node(CameraCOMP.new(), "cam1")
	GNTestAssert.assert_eq(node.node_type, "camera", "node_type")

func test_camera_comp_default_params() -> void:
	var node := _make_node(CameraCOMP.new(), "cam1")
	GNTestAssert.assert_approx(node.get_param_value("ty"), 1.0, 0.001, "cam default ty=1")
	GNTestAssert.assert_approx(node.get_param_value("tz"), 3.0, 0.001, "cam default tz=3")
	GNTestAssert.assert_approx(node.get_param_value("fov"), 75.0, 0.001, "cam default fov=75")

func test_camera_comp_cooks_without_input() -> void:
	var node := _make_node(CameraCOMP.new(), "cam1")
	_cook_no_input(node)
	# CameraCOMP returns null data — it provides a Camera3D scene node instead
	GNTestAssert.assert_not_null(node.get_camera(), "camera produces Camera3D node")


# ═══════════════════════════════════════════════════════════════════════════════
# LightCOMP
# ═══════════════════════════════════════════════════════════════════════════════

func test_light_comp_instantiate() -> void:
	var node := _make_node(LightCOMP.new(), "light1")
	GNTestAssert.assert_eq(node.node_type, "light", "node_type")

func test_light_comp_default_energy() -> void:
	var node := _make_node(LightCOMP.new(), "light1")
	GNTestAssert.assert_approx(node.get_param_value("energy"), 1.0, 0.001, "energy default 1.0")

func test_light_comp_cooks_without_input() -> void:
	var node := _make_node(LightCOMP.new(), "light1")
	_cook_no_input(node)
	# LightCOMP returns null data — it provides a Light3D scene node instead
	GNTestAssert.assert_not_null(node.get_light(), "light produces Light3D node")


# ═══════════════════════════════════════════════════════════════════════════════
# NullCOMP
# ═══════════════════════════════════════════════════════════════════════════════

func test_null_comp_instantiate() -> void:
	var node := _make_node(NullCOMP.new(), "null1")
	GNTestAssert.assert_eq(node.node_type, "null", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# EnvironmentCOMP
# ═══════════════════════════════════════════════════════════════════════════════

func test_environment_comp_instantiate() -> void:
	var node := _make_node(EnvironmentCOMP.new(), "env1")
	GNTestAssert.assert_eq(node.node_type, "environment", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# InstanceCOMP
# ═══════════════════════════════════════════════════════════════════════════════

func test_instance_comp_instantiate() -> void:
	var node := _make_node(InstanceCOMP.new(), "inst1")
	GNTestAssert.assert_eq(node.node_type, "instance", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# AnimationCOMP
# ═══════════════════════════════════════════════════════════════════════════════

func test_animation_comp_instantiate() -> void:
	var node := _make_node(AnimationCOMP.new(), "anim1")
	GNTestAssert.assert_eq(node.node_type, "animation", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# EnginesCOMP
# ═══════════════════════════════════════════════════════════════════════════════

func test_engines_comp_instantiate() -> void:
	var node := _make_node(EnginesCOMP.new(), "engines1")
	GNTestAssert.assert_eq(node.node_type, "engines", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# SwitchCOMP
# ═══════════════════════════════════════════════════════════════════════════════

func test_switch_comp_instantiate() -> void:
	var node := _make_node(SwitchCOMP.new(), "sw1")
	GNTestAssert.assert_eq(node.node_type, "switch", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# MergeCOMP
# ═══════════════════════════════════════════════════════════════════════════════

func test_merge_comp_instantiate() -> void:
	var node := _make_node(MergeCOMP.new(), "merge1")
	GNTestAssert.assert_eq(node.node_type, "merge", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# ReplicatorCOMP
# ═══════════════════════════════════════════════════════════════════════════════

func test_replicator_comp_instantiate() -> void:
	var node := _make_node(ReplicatorCOMP.new(), "rep1")
	GNTestAssert.assert_eq(node.node_type, "replicator", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# AreaCOMP
# ═══════════════════════════════════════════════════════════════════════════════

func test_area_comp_instantiate() -> void:
	var node := _make_node(AreaCOMP.new(), "area1")
	GNTestAssert.assert_eq(node.node_type, "area", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# RigidBodyCOMP
# ═══════════════════════════════════════════════════════════════════════════════

func test_rigid_body_comp_instantiate() -> void:
	var node := _make_node(RigidBodyCOMP.new(), "rb1")
	GNTestAssert.assert_eq(node.node_type, "rigid_body", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# StaticBodyCOMP
# ═══════════════════════════════════════════════════════════════════════════════

func test_static_body_comp_instantiate() -> void:
	var node := _make_node(StaticBodyCOMP.new(), "sb1")
	GNTestAssert.assert_eq(node.node_type, "static_body", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# SoftBodyCOMP
# ═══════════════════════════════════════════════════════════════════════════════

func test_soft_body_comp_instantiate() -> void:
	var node := _make_node(SoftBodyCOMP.new(), "soft1")
	GNTestAssert.assert_eq(node.node_type, "soft_body", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# JointCOMP
# ═══════════════════════════════════════════════════════════════════════════════

func test_joint_comp_instantiate() -> void:
	var node := _make_node(JointCOMP.new(), "joint1")
	GNTestAssert.assert_eq(node.node_type, "joint", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# GDScriptSCRIPT (GENERIC template)
# ═══════════════════════════════════════════════════════════════════════════════

func test_gdscript_script_generic_template() -> void:
	var node := _make_node(GDScriptSCRIPT.new(), "script1")
	GNTestAssert.assert_not_null(node, "GDScriptSCRIPT created")
	GNTestAssert.assert_eq(node.node_type, "script", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# SubNetworkNode / InTunnel / OutTunnel
# ═══════════════════════════════════════════════════════════════════════════════

func test_sub_network_node_instantiate() -> void:
	var node := _make_node(SubNetworkNode.new(), "subnet1")
	GNTestAssert.assert_eq(node.node_type, "sub_network", "node_type")

func test_in_tunnel_instantiate() -> void:
	var node := _make_node(InTunnel.new(), "in1")
	GNTestAssert.assert_eq(node.node_type, "in_tunnel", "node_type")

func test_out_tunnel_instantiate() -> void:
	var node := _make_node(OutTunnel.new(), "out1")
	GNTestAssert.assert_eq(node.node_type, "out_tunnel", "node_type")
# ═══════════════════════════════════════════════════════════════════════════════
# GNNativeCompiler
# ═══════════════════════════════════════════════════════════════════════════════

func test_gn_native_compiler_instantiate() -> void:
	var compiler := GNNativeCompiler.new()
	GNTestAssert.assert_not_null(compiler, "GNNativeCompiler created")


# ═══════════════════════════════════════════════════════════════════════════════
# GNCompatReportPanel
# ═══════════════════════════════════════════════════════════════════════════════

func test_gn_compat_report_panel_instantiate() -> void:
	var panel := GNCompatReportPanel.new()
	GNTestAssert.assert_not_null(panel, "GNCompatReportPanel created")
	panel.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
#  FeedbackCOMP (Gap Operator)
# ═══════════════════════════════════════════════════════════════════════════════

func test_feedback_comp_instantiate() -> void:
	var node := _make_node(FeedbackCOMP.new(), "fb1")
	GNTestAssert.assert_eq(node.node_type, "feedback", "node_type for FeedbackCOMP")

func test_feedback_comp_produces_output() -> void:
	var node := _make_node(FeedbackCOMP.new(), "fb1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNCompData, "no crash without input")


# ═══════════════════════════════════════════════════════════════════════════════
#  TimeCOMP (Gap Operator)
# ═══════════════════════════════════════════════════════════════════════════════

func test_time_comp_instantiate() -> void:
	var node := _make_node(TimeCOMP.new(), "time1")
	GNTestAssert.assert_eq(node.node_type, "time", "node_type for TimeCOMP")

func test_time_comp_default_params() -> void:
	var node := _make_node(TimeCOMP.new(), "time1")
	GNTestAssert.assert_approx(node.get_param_value("speed"), 1.0, 0.001, "default speed 1")

func test_time_comp_produces_output() -> void:
	var node := _make_node(TimeCOMP.new(), "time1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "timeCOMP produces output")


# ═══════════════════════════════════════════════════════════════════════════════
#  AudioListenerCOMP (Gap Operator)
# ═══════════════════════════════════════════════════════════════════════════════

func test_audio_listener_comp_instantiate() -> void:
	var node := _make_node(AudioListenerCOMP.new(), "listener1")
	GNTestAssert.assert_eq(node.node_type, "audiolistener", "node_type")

func test_audio_listener_comp_has_transforms() -> void:
	var node := _make_node(AudioListenerCOMP.new(), "listener1")
	# Check that standard COMP transform params exist
	GNTestAssert.assert_approx(node.get_param_value("tx"), 0.0, 0.001, "tx default 0")

func test_audio_listener_comp_produces_output() -> void:
	var node := _make_node(AudioListenerCOMP.new(), "listener1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNCompData, "comp output type")


# ═══════════════════════════════════════════════════════════════════════════════
#  AudioSourceCOMP (Gap Operator)
# ═══════════════════════════════════════════════════════════════════════════════

func test_audio_source_comp_instantiate() -> void:
	var node := _make_node(AudioSourceCOMP.new(), "src1")
	GNTestAssert.assert_eq(node.node_type, "audiosource", "node_type")

func test_audio_source_comp_default_params() -> void:
	var node := _make_node(AudioSourceCOMP.new(), "src1")
	GNTestAssert.assert_approx(node.get_param_value("volume_db"), 0.0, 0.001, "default volume 0 dB")
	GNTestAssert.assert_approx(node.get_param_value("max_distance"), 10.0, 0.001, "default max dist 10")

func test_audio_source_comp_produces_output() -> void:
	var node := _make_node(AudioSourceCOMP.new(), "src1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNCompData, "comp output type")
