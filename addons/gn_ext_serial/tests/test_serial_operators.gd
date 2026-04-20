extends Node
## Hand-written tests for gn_ext_serial operators.
## Tests scaffold mode behavior — serial operators produce valid DAT output
## even without native serial hardware.

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


# ═══════════════════════════════════════════════════════════════════════════════
# SerialSendDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_serial_send_instantiate() -> void:
	var node := _make_node(SerialSendDAT.new(), "ssend1")
	GNTestAssert.assert_not_null(node, "SerialSendDAT created")
	GNTestAssert.assert_eq(node.node_type, "serial_send", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.DAT, "family is DAT")

func test_serial_send_ports() -> void:
	var node := _make_node(SerialSendDAT.new(), "ssend2")
	GNTestAssert.assert_eq(node.input_ports.size(), 1, "1 input port")
	GNTestAssert.assert_eq(node.input_ports[0].family, GNFamily.Type.DAT, "input is DAT")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output port")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.DAT, "output is DAT")

func test_serial_send_parameters() -> void:
	var node := _make_node(SerialSendDAT.new(), "ssend3")
	GNTestAssert.assert_true(node.parameters.has("port"), "has port param")
	GNTestAssert.assert_true(node.parameters.has("baud_rate"), "has baud_rate")
	GNTestAssert.assert_true(node.parameters.has("line_ending"), "has line_ending")
	GNTestAssert.assert_true(node.parameters.has("active"), "has active")
	GNTestAssert.assert_true(node.parameters.has("send_now"), "has send_now pulse")
	GNTestAssert.assert_true(node.parameters.has("continuous"), "has continuous")
	GNTestAssert.assert_true(node.parameters.has("clear_log"), "has clear_log pulse")

func test_serial_send_param_defaults() -> void:
	var node := _make_node(SerialSendDAT.new(), "ssend4")
	GNTestAssert.assert_eq(node.get_param_value("port"), "COM3", "default port")
	GNTestAssert.assert_eq(node.get_param_value("baud_rate"), 9600, "default baud_rate")
	GNTestAssert.assert_eq(node.get_param_value("active"), false, "default active is false")
	GNTestAssert.assert_eq(node.get_param_value("continuous"), false, "default continuous")

func test_serial_send_cook_null() -> void:
	var node := _make_node(SerialSendDAT.new(), "ssend5")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "produces output even without input")

func test_serial_send_cook_produces_table() -> void:
	var node := _make_node(SerialSendDAT.new(), "ssend6")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out is GNTableData, "output is GNTableData")

func test_serial_send_time_dependent() -> void:
	var node := _make_node(SerialSendDAT.new(), "ssend7")
	GNTestAssert.assert_true(node.time_dependent, "time_dependent is true")

func test_serial_send_description() -> void:
	var node := _make_node(SerialSendDAT.new(), "ssend8")
	GNTestAssert.assert_true(not node.node_description.is_empty(), "has description")


# ═══════════════════════════════════════════════════════════════════════════════
# SerialReceiveDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_serial_receive_instantiate() -> void:
	var node := _make_node(SerialReceiveDAT.new(), "srecv1")
	GNTestAssert.assert_not_null(node, "SerialReceiveDAT created")
	GNTestAssert.assert_eq(node.node_type, "serial_receive", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.DAT, "family is DAT")

func test_serial_receive_ports() -> void:
	var node := _make_node(SerialReceiveDAT.new(), "srecv2")
	GNTestAssert.assert_eq(node.input_ports.size(), 0, "no input ports")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output port")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.DAT, "output is DAT")

func test_serial_receive_parameters() -> void:
	var node := _make_node(SerialReceiveDAT.new(), "srecv3")
	GNTestAssert.assert_true(node.parameters.has("port"), "has port param")
	GNTestAssert.assert_true(node.parameters.has("baud_rate"), "has baud_rate")
	GNTestAssert.assert_true(node.parameters.has("delimiter"), "has delimiter")
	GNTestAssert.assert_true(node.parameters.has("max_rows"), "has max_rows")
	GNTestAssert.assert_true(node.parameters.has("active"), "has active")
	GNTestAssert.assert_true(node.parameters.has("clear"), "has clear pulse")

func test_serial_receive_param_defaults() -> void:
	var node := _make_node(SerialReceiveDAT.new(), "srecv4")
	GNTestAssert.assert_eq(node.get_param_value("port"), "COM3", "default port")
	GNTestAssert.assert_eq(node.get_param_value("baud_rate"), 9600, "default baud_rate")
	GNTestAssert.assert_eq(node.get_param_value("max_rows"), 100, "default max_rows")
	GNTestAssert.assert_eq(node.get_param_value("active"), false, "default active is false")

func test_serial_receive_cook_null() -> void:
	var node := _make_node(SerialReceiveDAT.new(), "srecv5")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "produces output")

func test_serial_receive_cook_produces_table() -> void:
	var node := _make_node(SerialReceiveDAT.new(), "srecv6")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out is GNTableData, "output is GNTableData")

func test_serial_receive_time_dependent() -> void:
	var node := _make_node(SerialReceiveDAT.new(), "srecv7")
	GNTestAssert.assert_true(node.time_dependent, "time_dependent is true")
