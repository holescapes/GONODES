extends Node
## Tests for gn_ext_gpu_encode operators.

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
# MovieFileOutTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_movie_file_out_top_instantiate() -> void:
	var node := _make_node(MovieFileOutTOP.new(), "moout1")
	GNTestAssert.assert_not_null(node, "MovieFileOutTOP created")
	GNTestAssert.assert_eq(node.node_type, "moviefileouttop", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family is TOP")

func test_movie_file_out_top_ports() -> void:
	var node := _make_node(MovieFileOutTOP.new(), "moout2")
	GNTestAssert.assert_eq(node.input_ports.size(), 1, "1 input")
	GNTestAssert.assert_eq(node.input_ports[0].family, GNFamily.Type.TOP, "input is TOP")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output (pass-through)")

func test_movie_file_out_top_parameters() -> void:
	var node := _make_node(MovieFileOutTOP.new(), "moout3")
	GNTestAssert.assert_true(node.parameters.has("file_path"), "has file_path")
	GNTestAssert.assert_true(node.parameters.has("bitrate"), "has bitrate")
	GNTestAssert.assert_true(node.parameters.has("fps"), "has fps")
	GNTestAssert.assert_true(node.parameters.has("record"), "has record")

func test_movie_file_out_top_param_defaults() -> void:
	var node := _make_node(MovieFileOutTOP.new(), "moout4")
	GNTestAssert.assert_eq(node.get_param_value("fps"), 30, "default fps is 30")
	GNTestAssert.assert_eq(node.get_param_value("record"), false, "default record is false")

func test_movie_file_out_top_cook_null() -> void:
	var node := _make_node(MovieFileOutTOP.new(), "moout5")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "MovieFileOutTOP cook-null no crash")

func test_movie_file_out_top_is_sink() -> void:
	var node := _make_node(MovieFileOutTOP.new(), "moout6")
	GNTestAssert.assert_true(node.is_sink, "is_sink is true")

func test_movie_file_out_top_description() -> void:
	var node := _make_node(MovieFileOutTOP.new(), "moout7")
	GNTestAssert.assert_true(not node.node_description.is_empty(), "has description")
