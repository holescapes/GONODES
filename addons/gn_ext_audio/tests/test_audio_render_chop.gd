extends Node
## is_sink follows record / export_now without _pre_cook.


func _make_node(id: String) -> AudioRenderCHOP:
	var node := AudioRenderCHOP.new()
	node.initialize(id)
	add_child(node)
	return node


func test_audio_render_chop_is_sink_when_record_or_export() -> void:
	var node := _make_node("audiorender1")
	GNTestAssert.assert_false(node.is_sink, "Both off → not is_sink")
	node.set_param_value("record", true)
	GNTestAssert.assert_true(node.is_sink, "Record on → is_sink")
	node.set_param_value("record", false)
	GNTestAssert.assert_false(node.is_sink, "Record off → not is_sink")
	node.set_param_value("export_now", true)
	GNTestAssert.assert_true(node.is_sink, "Export on → is_sink")
	node.set_param_value("export_now", false)
	GNTestAssert.assert_false(node.is_sink, "Both off again → not is_sink")
