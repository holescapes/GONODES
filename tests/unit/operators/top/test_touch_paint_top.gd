extends Node
## Unit tests for TouchPaintTOP (CPU mask paint).

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


func test_touch_paint_instantiate() -> void:
	var node := _make_node(TouchPaintTOP.new(), "paint1")
	GNTestAssert.assert_eq(node.node_type, "touch_paint", "node_type")
	GNTestAssert.assert_true(node.time_dependent, "time_dependent")


func test_touch_paint_produces_texture() -> void:
	var node := _make_node(TouchPaintTOP.new(), "paint1") as TouchPaintTOP
	node.set_param_value("resolution", Vector2i(64, 64))
	node.set_param_value("paint", false)
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "output exists")
	GNTestAssert.assert_true(out is GNTextureData, "is GNTextureData")
	if out is GNTextureData:
		GNTestAssert.assert_eq(out.resolution, Vector2i(64, 64), "resolution")


func test_touch_paint_stroke_raises_center() -> void:
	var node := _make_node(TouchPaintTOP.new(), "paint1") as TouchPaintTOP
	node.set_param_value("resolution", Vector2i(64, 64))
	node.set_param_value("cx", 0.5)
	node.set_param_value("cy", 0.5)
	node.set_param_value("radius_px", 20.0)
	node.set_param_value("strength", 0.8)
	node.set_param_value("accumulate", true)
	node.set_param_value("paint", true)
	_cook_no_input(node)
	var mask := node.get_mask_image()
	GNTestAssert.assert_not_null(mask, "mask image")
	if mask != null:
		var center: float = mask.get_pixel(32, 32).r
		var corner: float = mask.get_pixel(0, 0).r
		GNTestAssert.assert_true(center > 0.3, "center painted (got %s)" % center)
		GNTestAssert.assert_true(corner < 0.05, "corner untouched (got %s)" % corner)


func test_touch_paint_clear_pulse() -> void:
	var node := _make_node(TouchPaintTOP.new(), "paint1") as TouchPaintTOP
	node.set_param_value("resolution", Vector2i(32, 32))
	node.set_param_value("cx", 0.5)
	node.set_param_value("cy", 0.5)
	node.set_param_value("radius_px", 16.0)
	node.set_param_value("strength", 1.0)
	node.set_param_value("paint", true)
	_cook_no_input(node)
	node.set_param_value("paint", false)
	node.set_param_value("clear", true)
	_cook_no_input(node)
	GNTestAssert.assert_eq(node.get_param_value("clear"), false, "clear auto-resets")
	var mask := node.get_mask_image()
	if mask != null:
		GNTestAssert.assert_approx(mask.get_pixel(16, 16).r, 0.0, 0.01, "cleared to zero")
