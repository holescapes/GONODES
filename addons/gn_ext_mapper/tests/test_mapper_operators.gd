extends Node
## Tests for gn_ext_mapper operators.

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


func _make_constant_tex(color: Color, res: Vector2i) -> GNTextureData:
	var img := Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	var td := GNTextureData.new()
	td.texture = tex
	td.valid = true
	return td


# ═══════════════════════════════════════════════════════════════════════════════
# BezierMapTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_bezier_map_top_instantiate() -> void:
	var node := _make_node(BezierMapTOP.new(), "bmap1")
	GNTestAssert.assert_not_null(node, "BezierMapTOP created")

func test_bezier_map_top_with_input() -> void:
	var node := _make_node(BezierMapTOP.new(), "bmap2")
	var tex := _make_constant_tex(Color.WHITE, Vector2i(64, 64))
	if tex == null:
		return
	var out := _cook_with(node, [tex] as Array[GNData])
	GNTestAssert.assert_not_null(out, "BezierMapTOP cooks with texture input")


# ═══════════════════════════════════════════════════════════════════════════════
# EdgeBlendTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_edge_blend_top_instantiate() -> void:
	var node := _make_node(EdgeBlendTOP.new(), "eblend1")
	GNTestAssert.assert_not_null(node, "EdgeBlendTOP created")

func test_edge_blend_top_with_input() -> void:
	var node := _make_node(EdgeBlendTOP.new(), "eblend2")
	var tex := _make_constant_tex(Color.WHITE, Vector2i(64, 64))
	if tex == null:
		return
	var out := _cook_with(node, [tex] as Array[GNData])
	GNTestAssert.assert_not_null(out, "EdgeBlendTOP cooks with texture input")


# ═══════════════════════════════════════════════════════════════════════════════
# GridWarpTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_grid_warp_top_instantiate() -> void:
	var node := _make_node(GridWarpTOP.new(), "gwarp1")
	GNTestAssert.assert_not_null(node, "GridWarpTOP created")

func test_grid_warp_top_with_input() -> void:
	var node := _make_node(GridWarpTOP.new(), "gwarp2")
	var tex := _make_constant_tex(Color.WHITE, Vector2i(64, 64))
	if tex == null:
		return
	var out := _cook_with(node, [tex] as Array[GNData])
	GNTestAssert.assert_not_null(out, "GridWarpTOP cooks with texture input")


# ═══════════════════════════════════════════════════════════════════════════════
# ProjectionMaskTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_projection_mask_top_instantiate() -> void:
	var node := _make_node(ProjectionMaskTOP.new(), "pmask1")
	GNTestAssert.assert_not_null(node, "ProjectionMaskTOP created")

func test_projection_mask_top_with_input() -> void:
	var node := _make_node(ProjectionMaskTOP.new(), "pmask2")
	var tex := _make_constant_tex(Color.WHITE, Vector2i(64, 64))
	if tex == null:
		return
	var out := _cook_with(node, [tex] as Array[GNData])
	GNTestAssert.assert_not_null(out, "ProjectionMaskTOP cooks with texture input")


# ═══════════════════════════════════════════════════════════════════════════════
# ProjectorBlendTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_projector_blend_top_instantiate() -> void:
	var node := _make_node(ProjectorBlendTOP.new(), "pblend1")
	GNTestAssert.assert_not_null(node, "ProjectorBlendTOP created")

func test_projector_blend_top_with_input() -> void:
	var node := _make_node(ProjectorBlendTOP.new(), "pblend2")
	var tex := _make_constant_tex(Color.WHITE, Vector2i(64, 64))
	if tex == null:
		return
	var out := _cook_with(node, [tex] as Array[GNData])
	GNTestAssert.assert_not_null(out, "ProjectorBlendTOP cooks with texture input")


# ═══════════════════════════════════════════════════════════════════════════════
# QuadMapTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_quad_map_top_instantiate() -> void:
	var node := _make_node(QuadMapTOP.new(), "qmap1")
	GNTestAssert.assert_not_null(node, "QuadMapTOP created")

func test_quad_map_top_with_input() -> void:
	var node := _make_node(QuadMapTOP.new(), "qmap2")
	var tex := _make_constant_tex(Color.WHITE, Vector2i(64, 64))
	if tex == null:
		return
	var out := _cook_with(node, [tex] as Array[GNData])
	GNTestAssert.assert_not_null(out, "QuadMapTOP cooks with texture input")


# ═══════════════════════════════════════════════════════════════════════════════
# StonerTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_stoner_top_instantiate() -> void:
	var node := _make_node(StonerTOP.new(), "stone1")
	GNTestAssert.assert_not_null(node, "StonerTOP created")

func test_stoner_top_with_input() -> void:
	var node := _make_node(StonerTOP.new(), "stone2")
	var tex := _make_constant_tex(Color.WHITE, Vector2i(64, 64))
	if tex == null:
		return
	var out := _cook_with(node, [tex] as Array[GNData])
	GNTestAssert.assert_not_null(out, "StonerTOP cooks with texture input")
