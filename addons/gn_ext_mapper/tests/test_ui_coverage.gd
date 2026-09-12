extends Node
## gn_ext_mapper — interactive panel coverage.


func _make_node(node: GNNode, id: String) -> GNNode:
	node.initialize(id)
	return node


func test_quad_map_panel_port() -> void:
	var node := _make_node(QuadMapTOP.new(), "quad_map1")
	GNTestAssert.assert_true(node.has_panel_output(), "QuadMapTOP has panel output")
	GNTestAssert.assert_eq(node.get_panel_port_index(), 1, "panel port index")


func test_quad_map_interactive_panel() -> void:
	var node := _make_node(QuadMapTOP.new(), "quad_map1")
	var panel: GNInteractivePanel = node._create_interactive_panel()
	GNTestAssert.assert_true(panel is MapperOverlay, "panel is MapperOverlay")
	GNTestAssert.assert_eq((panel as MapperOverlay).points.size(), 4, "four corners")


func test_mapper_overlay_pointer() -> void:
	var panel := MapperOverlay.new()
	panel.points = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)])
	panel.grab_radius_uv = 0.1
	panel.size = Vector2(200, 200)
	var hit := panel.hit_test_uv(Vector2(0.02, 0.02), 0.1)
	GNTestAssert.assert_eq(hit, 0, "hit top-left corner")
