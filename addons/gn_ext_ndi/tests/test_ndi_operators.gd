extends Node
## Tests for gn_ext_ndi operators.

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
# NDIInTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_ndi_in_top_instantiate() -> void:
	var node := _make_node(NDIInTOP.new(), "ndiin1")
	GNTestAssert.assert_not_null(node, "NDIInTOP created")
	GNTestAssert.assert_eq(node.node_type, "ndiin", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family is TOP")

func test_ndi_in_top_ports() -> void:
	var node := _make_node(NDIInTOP.new(), "ndiin2")
	GNTestAssert.assert_eq(node.input_ports.size(), 0, "no inputs")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.TOP, "output is TOP")

func test_ndi_in_top_parameters() -> void:
	var node := _make_node(NDIInTOP.new(), "ndiin3")
	GNTestAssert.assert_true(node.parameters.has("source"), "has source")
	GNTestAssert.assert_true(node.parameters.has("resolution"), "has resolution")
	GNTestAssert.assert_true(node.parameters.has("bandwidth"), "has bandwidth")
	GNTestAssert.assert_true(node.parameters.has("active"), "has active")

func test_ndi_in_top_cook_null() -> void:
	var node := _make_node(NDIInTOP.new(), "ndiin4")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "NDIInTOP cook-null no crash")

func test_ndi_in_top_time_dependent() -> void:
	var node := _make_node(NDIInTOP.new(), "ndiin5")
	GNTestAssert.assert_true(node.time_dependent, "time_dependent is true")


# ═══════════════════════════════════════════════════════════════════════════════
# NDIOutTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_ndi_out_top_instantiate() -> void:
	var node := _make_node(NDIOutTOP.new(), "ndiout1")
	GNTestAssert.assert_not_null(node, "NDIOutTOP created")
	GNTestAssert.assert_eq(node.node_type, "ndiout", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family is TOP")

func test_ndi_out_top_ports() -> void:
	var node := _make_node(NDIOutTOP.new(), "ndiout2")
	GNTestAssert.assert_eq(node.input_ports.size(), 1, "1 input")
	GNTestAssert.assert_eq(node.input_ports[0].family, GNFamily.Type.TOP, "input is TOP")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output (pass-through)")

func test_ndi_out_top_parameters() -> void:
	var node := _make_node(NDIOutTOP.new(), "ndiout3")
	GNTestAssert.assert_true(node.parameters.has("name"), "has name")
	GNTestAssert.assert_true(node.parameters.has("fps_n"), "has fps_n")
	GNTestAssert.assert_true(node.parameters.has("fps_d"), "has fps_d")
	GNTestAssert.assert_true(node.parameters.has("active"), "has active")

func test_ndi_out_top_cook_null() -> void:
	var node := _make_node(NDIOutTOP.new(), "ndiout4")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "NDIOutTOP cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# NDIAudioInCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_ndi_audio_in_chop_instantiate() -> void:
	var node := _make_node(NDIAudioInCHOP.new(), "ndiaudioin1")
	GNTestAssert.assert_not_null(node, "NDIAudioInCHOP created")
	GNTestAssert.assert_eq(node.node_type, "ndiaudioin", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.CHOP, "family is CHOP")

func test_ndi_audio_in_chop_ports() -> void:
	var node := _make_node(NDIAudioInCHOP.new(), "ndiaudioin2")
	GNTestAssert.assert_eq(node.input_ports.size(), 0, "no inputs")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.CHOP, "output is CHOP")

func test_ndi_audio_in_chop_parameters() -> void:
	var node := _make_node(NDIAudioInCHOP.new(), "ndiaudioin3")
	GNTestAssert.assert_true(node.parameters.has("source"), "has source")
	GNTestAssert.assert_true(node.parameters.has("bandwidth"), "has bandwidth")
	GNTestAssert.assert_true(node.parameters.has("active"), "has active")

func test_ndi_audio_in_chop_cook_null() -> void:
	var node := _make_node(NDIAudioInCHOP.new(), "ndiaudioin4")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "NDIAudioInCHOP cook-null no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# NDIAudioOutCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_ndi_audio_out_chop_instantiate() -> void:
	var node := _make_node(NDIAudioOutCHOP.new(), "ndiaudioout1")
	GNTestAssert.assert_not_null(node, "NDIAudioOutCHOP created")
	GNTestAssert.assert_eq(node.node_type, "ndiaudioout", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.CHOP, "family is CHOP")

func test_ndi_audio_out_chop_ports() -> void:
	var node := _make_node(NDIAudioOutCHOP.new(), "ndiaudioout2")
	GNTestAssert.assert_eq(node.input_ports.size(), 1, "1 input")
	GNTestAssert.assert_eq(node.input_ports[0].family, GNFamily.Type.CHOP, "input is CHOP")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output (pass-through)")

func test_ndi_audio_out_chop_parameters() -> void:
	var node := _make_node(NDIAudioOutCHOP.new(), "ndiaudioout3")
	GNTestAssert.assert_true(node.parameters.has("name"), "has name")
	GNTestAssert.assert_true(node.parameters.has("sample_rate"), "has sample_rate")
	GNTestAssert.assert_true(node.parameters.has("active"), "has active")

func test_ndi_audio_out_chop_cook_null() -> void:
	var node := _make_node(NDIAudioOutCHOP.new(), "ndiaudioout4")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "NDIAudioOutCHOP cook-null no crash")
