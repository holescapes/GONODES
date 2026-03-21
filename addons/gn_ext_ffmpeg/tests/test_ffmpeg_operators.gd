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


# ═══════════════════════════════════════════════════════════════════════════════
# FFmpegInTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_ffmpeg_in_top_instantiate() -> void:
	var node := _make_node(FFmpegInTOP.new(), "ffin1")
	GNTestAssert.assert_not_null(node, "FFmpegInTOP created")

func test_ffmpeg_in_top_set_file() -> void:
	var node := _make_node(FFmpegInTOP.new(), "ffin2")
	node.set_param_value("file_path", "test.mp4")
	var param: Variant = node.get_param_value("file_path")
	GNTestAssert.assert_eq(param, "test.mp4", "file_path param set")
