extends Node
## Tests for gn_ext_midi operators.

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
# RtMidiInCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_rt_midi_in_chop_instantiate() -> void:
	var node := _make_node(RtMidiInCHOP.new(), "rtmidiin1")
	GNTestAssert.assert_not_null(node, "RtMidiInCHOP created")
	GNTestAssert.assert_eq(node.node_type, "rtmidiin", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.CHOP, "family is CHOP")

func test_rt_midi_in_chop_ports() -> void:
	var node := _make_node(RtMidiInCHOP.new(), "rtmidiin2")
	GNTestAssert.assert_eq(node.input_ports.size(), 0, "no inputs")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.CHOP, "output is CHOP")

func test_rt_midi_in_chop_parameters() -> void:
	var node := _make_node(RtMidiInCHOP.new(), "rtmidiin3")
	GNTestAssert.assert_true(node.parameters.has("port"), "has port")
	GNTestAssert.assert_true(node.parameters.has("channel_filter"), "has channel_filter")
	GNTestAssert.assert_true(node.parameters.has("notes"), "has notes")
	GNTestAssert.assert_true(node.parameters.has("ccs"), "has ccs")
	GNTestAssert.assert_true(node.parameters.has("normalize"), "has normalize")

func test_rt_midi_in_chop_cook_null() -> void:
	var node := _make_node(RtMidiInCHOP.new(), "rtmidiin4")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "RtMidiInCHOP cook-null no crash")

func test_rt_midi_in_chop_time_dependent() -> void:
	var node := _make_node(RtMidiInCHOP.new(), "rtmidiin5")
	GNTestAssert.assert_true(node.time_dependent, "time_dependent is true")


# ═══════════════════════════════════════════════════════════════════════════════
# RtMidiOutCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_rt_midi_out_chop_instantiate() -> void:
	var node := _make_node(RtMidiOutCHOP.new(), "rtmidiout1")
	GNTestAssert.assert_not_null(node, "RtMidiOutCHOP created")
	GNTestAssert.assert_eq(node.node_type, "rtmidiout", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.CHOP, "family is CHOP")

func test_rt_midi_out_chop_ports() -> void:
	var node := _make_node(RtMidiOutCHOP.new(), "rtmidiout2")
	GNTestAssert.assert_eq(node.input_ports.size(), 1, "1 input")
	GNTestAssert.assert_eq(node.input_ports[0].family, GNFamily.Type.CHOP, "input is CHOP")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output")

func test_rt_midi_out_chop_parameters() -> void:
	var node := _make_node(RtMidiOutCHOP.new(), "rtmidiout3")
	GNTestAssert.assert_true(node.parameters.has("port"), "has port")
	GNTestAssert.assert_true(node.parameters.has("channel"), "has channel")
	GNTestAssert.assert_true(node.parameters.has("active"), "has active")
	GNTestAssert.assert_true(node.parameters.has("normalized_input"), "has normalized_input")

func test_rt_midi_out_chop_cook_null() -> void:
	var node := _make_node(RtMidiOutCHOP.new(), "rtmidiout4")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "RtMidiOutCHOP cook-null no crash")

func test_rt_midi_out_chop_is_sink() -> void:
	var node := _make_node(RtMidiOutCHOP.new(), "rtmidiout5")
	GNTestAssert.assert_true(node.is_sink, "is_sink is true")


func test_rt_midi_out_chop_resets_note_states_on_port_open() -> void:
	var node := _make_node(RtMidiOutCHOP.new(), "rtmidiout6")
	node._prev_note_states[60] = 101.0
	GNTestAssert.assert_eq(node._prev_note_states[60], 101.0, "seeded non-zero held note state")
	node._reset_note_states()
	GNTestAssert.assert_eq(node._prev_note_states[60], 0.0,
		"note state cleared so held input sends note-on after port open")


func test_rt_midi_out_chop_deactivate_resets_port_state() -> void:
	var node := _make_node(RtMidiOutCHOP.new(), "rtmidiout8")
	node._prev_port = 2
	node._port_open = true
	node._prev_note_states[60] = 101.0
	node._deactivate_midi_output()
	GNTestAssert.assert_eq(node._prev_port, -1,
		"deactivate clears prev port so next active cook reopens")
	GNTestAssert.assert_false(node._port_open, "deactivate closes port")


func test_rt_midi_out_chop_port_list_change_forces_reopen() -> void:
	if not ClassDB.class_exists("GNMidiOut"):
		GNTestAssert.assert_true(true, "GNMidiOut unavailable — reset test covers open path")
		return
	var node := _make_node(RtMidiOutCHOP.new(), "rtmidiout7")
	node._prev_port = 0
	node._prev_port_list = PackedStringArray(["__stale_port_name__"])
	node._check_port_list_changed()
	GNTestAssert.assert_eq(node._prev_port, -1,
		"device list change forces port reopen even when index unchanged")
	var current_ports: PackedStringArray = ClassDB.class_call_static(&"GNMidiOut", &"get_port_list")
	GNTestAssert.assert_eq(node._prev_port_list, current_ports, "port list cache updated")
