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
# PythonSCRIPT — consolidated Python scripting node
# ═══════════════════════════════════════════════════════════════════════════════

func test_python_script_instantiate() -> void:
	var node := _make_node(PythonSCRIPT.new(), "pythonscript1")
	GNTestAssert.assert_not_null(node, "PythonSCRIPT created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.SCRIPT, "PythonSCRIPT family is SCRIPT")


func test_python_script_default_output() -> void:
	var node := _make_node(PythonSCRIPT.new(), "pythonscript_default")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "Default has 1 output")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.CHOP, "Default output is CHOP")


func test_python_script_preview_default() -> void:
	var node := _make_node(PythonSCRIPT.new(), "pythonscript_preview")
	var label := Label.new()
	node.update_preview_control(label)
	# No cook yet, preview should be empty
	GNTestAssert.assert_eq(label.text, "", "Preview empty before first cook")
	label.free()
