extends Node
## Tests for gn_ext_user_native operators.

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


# ═══════════════════════════════════════════════════════════════════════════════
# UserNativeCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_user_native_chop_instantiate() -> void:
	var node := _make_node(UserNativeCHOP.new(), "usernativechop1")
	GNTestAssert.assert_not_null(node, "UserNativeCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# UserNativeTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_user_native_top_instantiate() -> void:
	var node := _make_node(UserNativeTOP.new(), "usernativetop1")
	GNTestAssert.assert_not_null(node, "UserNativeTOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# UserNativeSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_user_native_sop_instantiate() -> void:
	var node := _make_node(UserNativeSOP.new(), "usernativesop1")
	GNTestAssert.assert_not_null(node, "UserNativeSOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# UserNativeDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_user_native_dat_instantiate() -> void:
	var node := _make_node(UserNativeDAT.new(), "usernativedat1")
	GNTestAssert.assert_not_null(node, "UserNativeDAT created")


# ═══════════════════════════════════════════════════════════════════════════════
# UserNativeIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_user_native_img_instantiate() -> void:
	var node := _make_node(UserNativeIMG.new(), "usernativeimg1")
	GNTestAssert.assert_not_null(node, "UserNativeIMG created")
