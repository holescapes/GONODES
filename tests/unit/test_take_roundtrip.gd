extends Node
## Phase 4d — GNTakeManager capture / apply / revert / file round-trip.


func test_take_apply_revert_and_file() -> void:
	var net := GNNetwork.new()
	var node := ConstantCHOP.new()
	node.initialize("const1")
	net.add_node(node)
	node.set_param_value("value0", 1.0)

	var mgr := GNTakeManager.new()
	mgr.network = net
	mgr.capture_base()
	node.set_param_value("value0", 9.0)
	mgr.capture_take("Intense")
	GNTestAssert.assert_eq(mgr.get_take_override_count("Intense"), 1, "sparse delta is one param")

	mgr.revert_to_base()
	GNTestAssert.assert_approx(float(node.get_param_value("value0")), 1.0, 0.001, "revert restores base")
	GNTestAssert.assert_eq(mgr.active_take, "", "active take cleared")

	mgr.apply_take("Intense")
	GNTestAssert.assert_approx(float(node.get_param_value("value0")), 9.0, 0.001, "apply restores take")
	GNTestAssert.assert_eq(mgr.active_take, "Intense", "active take name")

	var path := "user://pbaudit_take_roundtrip.gntake"
	GNTestAssert.assert_true(mgr.save_to_file(path), "save_to_file")
	var loaded := GNTakeManager.new()
	loaded.network = net
	GNTestAssert.assert_true(loaded.load_from_file(path), "load_from_file")
	node.set_param_value("value0", 0.0)
	loaded.apply_take("Intense")
	GNTestAssert.assert_approx(float(node.get_param_value("value0")), 9.0, 0.001, "loaded take applies")

	var spare := GNParameter.create_float("gain", 0.25)
	node.add_spare_parameter(spare)
	node.set_param_value("gain", 3.0)
	mgr.capture_base()
	node.set_param_value("gain", 8.0)
	mgr.capture_take("SpareCheck")
	GNTestAssert.assert_eq(mgr.get_take_override_count("SpareCheck"), 1, "spare param captured in take delta")

	mgr.revert_to_base()
	GNTestAssert.assert_approx(float(node.get_param_value("gain")), 3.0, 0.001, "revert restores spare base")

	mgr.apply_take("SpareCheck")
	GNTestAssert.assert_approx(float(node.get_param_value("gain")), 8.0, 0.001, "apply restores spare take")
