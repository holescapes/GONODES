extends Node
## Tests for gn_ext_ffmpeg operators.

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
# FFmpegInTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_ffmpeg_in_top_instantiate() -> void:
	var node := _make_node(FFmpegInTOP.new(), "ffin1")
	GNTestAssert.assert_not_null(node, "FFmpegInTOP created")
	GNTestAssert.assert_eq(node.node_type, "ffmpegin", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family is TOP")

func test_ffmpeg_in_top_ports() -> void:
	var node := _make_node(FFmpegInTOP.new(), "ffin2")
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "1 output")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.TOP, "output is TOP")

func test_ffmpeg_in_top_parameters() -> void:
	var node := _make_node(FFmpegInTOP.new(), "ffin3")
	GNTestAssert.assert_true(node.parameters.has("file"), "has file param")

func test_ffmpeg_in_top_set_file() -> void:
	var node := _make_node(FFmpegInTOP.new(), "ffin4")
	node.set_param_value("file", "test.mp4")
	GNTestAssert.assert_eq(node.get_param_value("file"), "test.mp4", "file param set")

func test_ffmpeg_in_top_cook_null() -> void:
	var node := _make_node(FFmpegInTOP.new(), "ffin5")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "FFmpegInTOP cook-null no crash")

func test_ffmpeg_in_top_description() -> void:
	var node := _make_node(FFmpegInTOP.new(), "ffin6")
	GNTestAssert.assert_true(not node.node_description.is_empty(), "has description")
