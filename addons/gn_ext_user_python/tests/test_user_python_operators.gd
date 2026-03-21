extends Node
## Tests for gn_ext_user_python operators.

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
# UserPythonCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_user_python_chop_instantiate() -> void:
	var node := _make_node(UserPythonCHOP.new(), "userpythonchop1")
	GNTestAssert.assert_not_null(node, "UserPythonCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# UserPythonTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_user_python_top_instantiate() -> void:
	var node := _make_node(UserPythonTOP.new(), "userpythontop1")
	GNTestAssert.assert_not_null(node, "UserPythonTOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# UserPythonSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_user_python_sop_instantiate() -> void:
	var node := _make_node(UserPythonSOP.new(), "userpythonsop1")
	GNTestAssert.assert_not_null(node, "UserPythonSOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# UserPythonDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_user_python_dat_instantiate() -> void:
	var node := _make_node(UserPythonDAT.new(), "userpythondat1")
	GNTestAssert.assert_not_null(node, "UserPythonDAT created")


# ═══════════════════════════════════════════════════════════════════════════════
# UserPythonIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_user_python_img_instantiate() -> void:
	var node := _make_node(UserPythonIMG.new(), "userpythonimg1")
	GNTestAssert.assert_not_null(node, "UserPythonIMG created")
