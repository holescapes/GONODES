extends Node
## Tests for gn_ext_video_capture operators.

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
# VideoDeviceInIMG
# ═══════════════════════════════════════════════════════════════════════════════

func test_video_device_in_img_instantiate() -> void:
	var node := _make_node(VideoDeviceInIMG.new(), "vdevice1")
	GNTestAssert.assert_not_null(node, "VideoDeviceInIMG created")
