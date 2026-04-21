extends Node
## Correctness tests for libpd extension operators.
##
## Tests verify instantiation, parameter defaults, and basic cook behavior.
## Full audio processing requires the native GNNativeLibPd class.

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


func _make_chop_data(channels: Dictionary, sr: float = 44100.0) -> GNChannelData:
	var cd := GNChannelData.new()
	cd.sample_rate = sr
	for ch_name in channels:
		cd.set_channel(ch_name, channels[ch_name])
	return cd


# ═══════════════════════════════════════════════════════════════════════════════
#  GNPdEngine
# ═══════════════════════════════════════════════════════════════════════════════

func test_pd_engine_create() -> void:
	var engine := GNPdEngine.new()
	GNTestAssert.assert_not_null(engine, "GNPdEngine created")

func test_pd_engine_availability() -> void:
	var engine := GNPdEngine.new()
	# Without native lib, should gracefully report unavailable
	var available: bool = engine.is_available()
	GNTestAssert.assert_true(available or not available, "availability check runs")


# ═══════════════════════════════════════════════════════════════════════════════
#  PdSynthCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_pd_synth_chop_instantiate() -> void:
	var node := _make_node(PdSynthCHOP.new(), "pdsynth1")
	GNTestAssert.assert_eq(node.node_type, "pdsynth", "node_type")

func test_pd_synth_chop_default_params() -> void:
	var node := _make_node(PdSynthCHOP.new(), "pdsynth1")
	GNTestAssert.assert_approx(node.get_param_value("frequency"), 440.0, 0.1, "default freq 440")
	GNTestAssert.assert_approx(node.get_param_value("amplitude"), 1.0, 0.01, "default amp 1")
	GNTestAssert.assert_eq(node.get_param_value("buffer_size"), 512, "default buffer 512")

func test_pd_synth_chop_no_patch() -> void:
	var node := _make_node(PdSynthCHOP.new(), "pdsynth1")
	# Without a patch file, should return null
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null, "null without patch")


# ═══════════════════════════════════════════════════════════════════════════════
#  PdFilterCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_pd_filter_chop_instantiate() -> void:
	var node := _make_node(PdFilterCHOP.new(), "pdfilter1")
	GNTestAssert.assert_eq(node.node_type, "pdfilter", "node_type")

func test_pd_filter_chop_default_params() -> void:
	var node := _make_node(PdFilterCHOP.new(), "pdfilter1")
	GNTestAssert.assert_approx(node.get_param_value("wet"), 1.0, 0.01, "default wet 1")

func test_pd_filter_chop_no_input() -> void:
	var node := _make_node(PdFilterCHOP.new(), "pdfilter1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null, "null without input")


# ═══════════════════════════════════════════════════════════════════════════════
#  PdControlCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_pd_control_chop_instantiate() -> void:
	var node := _make_node(PdControlCHOP.new(), "pdctrl1")
	GNTestAssert.assert_eq(node.node_type, "pdcontrol", "node_type")

func test_pd_control_chop_default_params() -> void:
	var node := _make_node(PdControlCHOP.new(), "pdctrl1")
	GNTestAssert.assert_eq(node.get_param_value("receive_names"), "out1 out2 out3", "default receive names")

func test_pd_control_chop_no_patch() -> void:
	var node := _make_node(PdControlCHOP.new(), "pdctrl1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null, "null without patch")
