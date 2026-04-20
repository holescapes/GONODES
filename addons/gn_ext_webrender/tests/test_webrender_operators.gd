extends Node
## Hand-written tests for gn_ext_webrender operators.
## CEF is not available in headless mode, so tests verify structure and
## graceful fallback behavior.

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
# WebRenderTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_webrender_instantiate() -> void:
	var node := _make_node(WebRenderTOP.new(), "web1")
	GNTestAssert.assert_not_null(node, "WebRenderTOP created")
	GNTestAssert.assert_eq(node.node_type, "webrender", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family is TOP")

func test_webrender_ports() -> void:
	var node := _make_node(WebRenderTOP.new(), "web2")
	GNTestAssert.assert_eq(node.input_ports.size(), 0, "no inputs")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output port")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.TOP, "output is TOP")

func test_webrender_parameters() -> void:
	var node := _make_node(WebRenderTOP.new(), "web3")
	GNTestAssert.assert_true(node.parameters.has("mode"), "has mode param")
	GNTestAssert.assert_true(node.parameters.has("url"), "has url param")
	GNTestAssert.assert_true(node.parameters.has("html"), "has html param")
	GNTestAssert.assert_true(node.parameters.has("resolution"), "has resolution param")
	GNTestAssert.assert_true(node.parameters.has("fps"), "has fps param")
	GNTestAssert.assert_true(node.parameters.has("javascript"), "has javascript param")
	GNTestAssert.assert_true(node.parameters.has("active"), "has active param")

func test_webrender_param_defaults() -> void:
	var node := _make_node(WebRenderTOP.new(), "web4")
	GNTestAssert.assert_eq(node.get_param_value("mode"), 0, "default mode is URL (0)")
	GNTestAssert.assert_eq(node.get_param_value("fps"), 30, "default fps is 30")
	GNTestAssert.assert_eq(node.get_param_value("active"), true, "default active is true")

func test_webrender_cook_null() -> void:
	var node := _make_node(WebRenderTOP.new(), "web5")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "WebRenderTOP cook-null no crash")

func test_webrender_time_dependent() -> void:
	var node := _make_node(WebRenderTOP.new(), "web6")
	GNTestAssert.assert_true(node.time_dependent, "time_dependent is true")

func test_webrender_description() -> void:
	var node := _make_node(WebRenderTOP.new(), "web7")
	GNTestAssert.assert_true(not node.node_description.is_empty(), "has description")

func test_webrender_set_url() -> void:
	var node := _make_node(WebRenderTOP.new(), "web8")
	node.set_param_value("url", "https://example.com")
	GNTestAssert.assert_eq(node.get_param_value("url"), "https://example.com", "url param set")

func test_webrender_set_html() -> void:
	var node := _make_node(WebRenderTOP.new(), "web9")
	node.set_param_value("html", "<h1>Test</h1>")
	GNTestAssert.assert_eq(node.get_param_value("html"), "<h1>Test</h1>", "html param set")
