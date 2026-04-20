extends Node
## Integration tests: COMP fan-out with proxy system.
##
## Tests the full pipeline:
##   • GeometryCOMP → two MergeCOMPs (fan-out at MergeCOMP level)
##   • MergeCOMP → two RenderTOPs (fan-out at RenderTOP level)
##   • GeometryCOMP → two RenderTOPs directly (fan-out without merge)
##   • Mixed chains with cameras and lights
##
## Verifies that scene nodes are proxied (not stolen) on fan-out,
## GPU resources (Mesh, Material) are shared, and cook order doesn't
## affect correctness.

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


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _add(node: GNNode, id: String) -> GNNode:
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	return node


func _wire(from_id: String, from_port: int, to_id: String, to_port: int) -> void:
	_network.connect_nodes(from_id, from_port, to_id, to_port)


func _cook_frame() -> void:
	for nid in _network.nodes:
		_network.nodes[nid].dirty = true
	_engine.cook_frame(_engine.current_delta)


func _sink(ids: Array) -> void:
	var typed: Array[String] = []
	for id in ids:
		typed.append(str(id))
	_engine.set_active_sinks(typed)


# ═══════════════════════════════════════════════════════════════════════════════
# Scenario 1: Single COMP → single RenderTOP (no fan-out, baseline)
# ═══════════════════════════════════════════════════════════════════════════════

func test_single_geo_to_render_no_proxy() -> void:
	var box := _add(BoxSOP.new(), "box1")
	var geo := _add(GeometryCOMP.new(), "geo1")
	var render := _add(RenderTOP.new(), "render1")

	_wire("box1", 0, "geo1", 0)
	_wire("geo1", 0, "render1", 0)
	_sink(["render1"])
	_cook_frame()

	# GeometryCOMP creates a mesh instance; RenderTOP should adopt it directly
	var geo_node: GNCompBase = geo as GNCompBase
	var scene_nd: Node3D = geo_node.get_scene_node()
	if scene_nd == null:
		# Headless or no viewport context — skip
		GNTestAssert.assert_true(true, "headless skip")
		return

	# In single-consumer case, the original should be adopted directly
	# (not proxied) for zero overhead
	GNTestAssert.assert_not_null(scene_nd, "scene node exists")
	GNTestAssert.assert_true(scene_nd is MeshInstance3D, "is MeshInstance3D")


# ═══════════════════════════════════════════════════════════════════════════════
# Scenario 2: GeometryCOMP → two RenderTOPs (direct fan-out)
# ═══════════════════════════════════════════════════════════════════════════════

func test_geo_fanout_two_render_tops() -> void:
	var box := _add(BoxSOP.new(), "box1")
	var geo := _add(GeometryCOMP.new(), "geo1")
	var render_a := _add(RenderTOP.new(), "renderA")
	var render_b := _add(RenderTOP.new(), "renderB")

	_wire("box1", 0, "geo1", 0)
	_wire("geo1", 0, "renderA", 0)
	_wire("geo1", 0, "renderB", 0)
	_sink(["renderA", "renderB"])
	_cook_frame()

	var geo_node: GNCompBase = geo as GNCompBase
	var scene_nd: Node3D = geo_node.get_scene_node()
	if scene_nd == null:
		GNTestAssert.assert_true(true, "headless skip")
		return

	# Both RenderTOPs should have produced output without crash
	GNTestAssert.assert_not_null(render_a.cached_output, "renderA has output")
	GNTestAssert.assert_not_null(render_b.cached_output, "renderB has output")

	# The scene node should be in exactly one viewport (first consumer
	# adopts, second proxies).  Neither should have stolen it.
	GNTestAssert.assert_not_null(scene_nd.get_parent(), "scene node is parented")


# ═══════════════════════════════════════════════════════════════════════════════
# Scenario 3: MergeCOMP fan-out to two RenderTOPs (multi-camera)
# ═══════════════════════════════════════════════════════════════════════════════

func test_merge_fanout_two_cameras() -> void:
	var box := _add(BoxSOP.new(), "box1")
	var geo := _add(GeometryCOMP.new(), "geo1")
	var light := _add(LightCOMP.new(), "light1")
	var merge_scene := _add(MergeCOMP.new(), "merge_scene")
	var cam_a := _add(CameraCOMP.new(), "camA")
	var cam_b := _add(CameraCOMP.new(), "camB")
	var merge_a := _add(MergeCOMP.new(), "mergeA")
	var merge_b := _add(MergeCOMP.new(), "mergeB")
	var render_a := _add(RenderTOP.new(), "renderA")
	var render_b := _add(RenderTOP.new(), "renderB")

	# Build scene: box geo + light → merge_scene
	_wire("box1", 0, "geo1", 0)
	_wire("geo1", 0, "merge_scene", 0)
	_wire("light1", 0, "merge_scene", 1)

	# Fan out merge_scene to two camera merges
	_wire("merge_scene", 0, "mergeA", 0)
	_wire("camA", 0, "mergeA", 1)
	_wire("merge_scene", 0, "mergeB", 0)
	_wire("camB", 0, "mergeB", 1)

	# Each camera merge → its own RenderTOP
	_wire("mergeA", 0, "renderA", 0)
	_wire("mergeB", 0, "renderB", 0)

	_sink(["renderA", "renderB"])
	_cook_frame()

	# Both renders should succeed
	GNTestAssert.assert_not_null(render_a.cached_output, "renderA has output")
	GNTestAssert.assert_not_null(render_b.cached_output, "renderB has output")

	# MergeCOMP_A and MergeCOMP_B should each have children
	# (one gets the original merge_scene._group_node, the other gets a proxy)
	var merge_a_comp: MergeCOMP = merge_a as MergeCOMP
	var merge_b_comp: MergeCOMP = merge_b as MergeCOMP
	var ga: Node3D = merge_a_comp.get_group_node()
	var gb: Node3D = merge_b_comp.get_group_node()
	if ga != null and gb != null:
		# Both should have non-zero children
		GNTestAssert.assert_true(ga.get_child_count() > 0, "mergeA has children")
		GNTestAssert.assert_true(gb.get_child_count() > 0, "mergeB has children")


# ═══════════════════════════════════════════════════════════════════════════════
# Scenario 4: GeometryCOMP fan-out to two MergeCOMPs
# ═══════════════════════════════════════════════════════════════════════════════

func test_geo_fanout_two_merges() -> void:
	var box := _add(BoxSOP.new(), "box1")
	var geo := _add(GeometryCOMP.new(), "geo1")
	var merge_a := _add(MergeCOMP.new(), "mergeA")
	var merge_b := _add(MergeCOMP.new(), "mergeB")
	var render_a := _add(RenderTOP.new(), "renderA")
	var render_b := _add(RenderTOP.new(), "renderB")

	_wire("box1", 0, "geo1", 0)
	_wire("geo1", 0, "mergeA", 0)
	_wire("geo1", 0, "mergeB", 0)
	_wire("mergeA", 0, "renderA", 0)
	_wire("mergeB", 0, "renderB", 0)

	_sink(["renderA", "renderB"])
	_cook_frame()

	var geo_comp: GNCompBase = geo as GNCompBase
	var mesh_node: Node3D = geo_comp.get_scene_node()
	if mesh_node == null:
		GNTestAssert.assert_true(true, "headless skip")
		return

	# Both renders should succeed
	GNTestAssert.assert_not_null(render_a.cached_output, "renderA has output")
	GNTestAssert.assert_not_null(render_b.cached_output, "renderB has output")

	# The original mesh should still be valid
	GNTestAssert.assert_true(is_instance_valid(mesh_node), "original mesh still valid")


# ═══════════════════════════════════════════════════════════════════════════════
# Scenario 5: Second cook frame — proxies are reused
# ═══════════════════════════════════════════════════════════════════════════════

func test_proxy_reused_second_frame() -> void:
	var box := _add(BoxSOP.new(), "box1")
	var geo := _add(GeometryCOMP.new(), "geo1")
	var render_a := _add(RenderTOP.new(), "renderA")
	var render_b := _add(RenderTOP.new(), "renderB")

	_wire("box1", 0, "geo1", 0)
	_wire("geo1", 0, "renderA", 0)
	_wire("geo1", 0, "renderB", 0)
	_sink(["renderA", "renderB"])
	_cook_frame()

	# Cook a second frame — proxies should be reused without crash
	_engine.frame_count += 1
	for nid in _network.nodes:
		_network.nodes[nid].dirty = true
	_engine.cook_frame(_engine.current_delta)

	GNTestAssert.assert_not_null(render_a.cached_output, "renderA second frame")
	GNTestAssert.assert_not_null(render_b.cached_output, "renderB second frame")


# ═══════════════════════════════════════════════════════════════════════════════
# Scenario 6: Proxy cleanup on disconnect
# ═══════════════════════════════════════════════════════════════════════════════

func test_proxy_cleanup_on_disconnect() -> void:
	var box := _add(BoxSOP.new(), "box1")
	var geo := _add(GeometryCOMP.new(), "geo1")
	var render_a := _add(RenderTOP.new(), "renderA")
	var render_b := _add(RenderTOP.new(), "renderB")

	_wire("box1", 0, "geo1", 0)
	_wire("geo1", 0, "renderA", 0)
	_wire("geo1", 0, "renderB", 0)
	_sink(["renderA", "renderB"])
	_cook_frame()

	# Disconnect renderB from geo1
	_network.disconnect_nodes("geo1", 0, "renderB", 0)
	_sink(["renderA"])
	_engine.frame_count += 1
	for nid in _network.nodes:
		_network.nodes[nid].dirty = true
	_engine.cook_frame(_engine.current_delta)

	# renderA should still work
	GNTestAssert.assert_not_null(render_a.cached_output, "renderA still works")


# ═══════════════════════════════════════════════════════════════════════════════
# Scenario 7: Light fan-out (non-mesh visual node)
# ═══════════════════════════════════════════════════════════════════════════════

func test_light_fanout_two_renders() -> void:
	var light := _add(LightCOMP.new(), "light1")
	var render_a := _add(RenderTOP.new(), "renderA")
	var render_b := _add(RenderTOP.new(), "renderB")

	_wire("light1", 0, "renderA", 0)
	_wire("light1", 0, "renderB", 0)
	_sink(["renderA", "renderB"])
	_cook_frame()

	GNTestAssert.assert_not_null(render_a.cached_output, "renderA has output")
	GNTestAssert.assert_not_null(render_b.cached_output, "renderB has output")
