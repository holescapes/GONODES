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


# ═══════════════════════════════════════════════════════════════════════════════
# RtMidiInCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_rt_midi_in_chop_instantiate() -> void:
	var node := _make_node(RtMidiInCHOP.new(), "rtmidiin1")
	GNTestAssert.assert_not_null(node, "RtMidiInCHOP created")


# ═══════════════════════════════════════════════════════════════════════════════
# RtMidiOutCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_rt_midi_out_chop_instantiate() -> void:
	var node := _make_node(RtMidiOutCHOP.new(), "rtmidiout1")
	GNTestAssert.assert_not_null(node, "RtMidiOutCHOP created")
