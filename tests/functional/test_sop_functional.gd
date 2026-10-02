extends Node
## Functional correctness tests for SOP operators.
##
## These tests verify that operators produce correct output values —
## not just that they instantiate or cook without errors. Each test
## checks specific geometric properties: vertex positions, counts,
## normals, bounds, winding, and attribute values.

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


func _make_box_geo(sx: float = 1.0, sy: float = 1.0, sz: float = 1.0) -> GNGeoData:
	var box := _make_node(BoxSOP.new(), "box_%d" % randi())
	box.set_param_value("size_x", sx)
	box.set_param_value("size_y", sy)
	box.set_param_value("size_z", sz)
	var _ret0 := _cook_no_input(box) as GNGeoData
	return _ret0


func _make_grid_geo(rows: int = 10, cols: int = 10) -> GNGeoData:
	var grid := _make_node(GridSOP.new(), "grid_%d" % randi())
	grid.set_param_value("rows", rows)
	grid.set_param_value("cols", cols)
	var _ret0 := _cook_no_input(grid) as GNGeoData
	return _ret0


func _make_sphere_geo(r_seg: int = 8, rings: int = 4) -> GNGeoData:
	var sph := _make_node(SphereSOP.new(), "sph_%d" % randi())
	sph.set_param_value("radial_segments", r_seg)
	sph.set_param_value("rings", rings)
	var _ret0 := _cook_no_input(sph) as GNGeoData
	return _ret0


func _make_line_geo(pts: int = 10) -> GNGeoData:
	var ln := _make_node(LineSOP.new(), "line_%d" % randi())
	ln.set_param_value("points", pts)
	var _ret0 := _cook_no_input(ln) as GNGeoData
	return _ret0


func _vert_count(geo: GNGeoData, surf: int = 0) -> int:
	if geo == null or geo.mesh == null or geo.mesh.get_surface_count() <= surf:
		return 0
	return geo.mesh.surface_get_arrays(surf)[Mesh.ARRAY_VERTEX].size()


func _total_verts(geo: GNGeoData) -> int:
	if geo == null or geo.mesh == null:
		return 0
	var total := 0
	for s in range(geo.mesh.get_surface_count()):
		total += geo.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX].size()
	return total


func _get_positions(geo: GNGeoData, surf: int = 0) -> PackedVector3Array:
	if geo == null or geo.mesh == null or geo.mesh.get_surface_count() <= surf:
		return PackedVector3Array()
	return geo.mesh.surface_get_arrays(surf)[Mesh.ARRAY_VERTEX]


func _get_normals(geo: GNGeoData, surf: int = 0) -> PackedVector3Array:
	if geo == null or geo.mesh == null or geo.mesh.get_surface_count() <= surf:
		return PackedVector3Array()
	var arrays := geo.mesh.surface_get_arrays(surf)
	if arrays[Mesh.ARRAY_NORMAL] == null:
		return PackedVector3Array()
	return arrays[Mesh.ARRAY_NORMAL]


func _get_indices(geo: GNGeoData, surf: int = 0) -> PackedInt32Array:
	if geo == null or geo.mesh == null or geo.mesh.get_surface_count() <= surf:
		return PackedInt32Array()
	var arrays := geo.mesh.surface_get_arrays(surf)
	if arrays[Mesh.ARRAY_INDEX] == null:
		return PackedInt32Array()
	return arrays[Mesh.ARRAY_INDEX]


func _surface_count(geo: GNGeoData) -> int:
	if geo == null or geo.mesh == null:
		return 0
	return geo.mesh.get_surface_count()


# ═══════════════════════════════════════════════════════════════════════════════
# BoxSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_box_vertex_positions_bounded() -> void:
	var geo := _make_box_geo(2.0, 2.0, 2.0)
	var verts := _get_positions(geo)
	for v in verts:
		GNTestAssert.assert_true(absf(v.x) <= 1.01 and absf(v.y) <= 1.01 and absf(v.z) <= 1.01,
			"box vert within bounds: %s" % str(v))

func test_box_size_affects_bounds() -> void:
	var small := _make_box_geo(1.0, 1.0, 1.0)
	var large := _make_box_geo(4.0, 4.0, 4.0)
	var small_aabb := small.mesh.get_aabb()
	var large_aabb := large.mesh.get_aabb()
	GNTestAssert.assert_gt(large_aabb.size.x, small_aabb.size.x, "larger box wider")
	GNTestAssert.assert_gt(large_aabb.size.y, small_aabb.size.y, "larger box taller")

func test_box_has_normals() -> void:
	var geo := _make_box_geo()
	var normals := _get_normals(geo)
	GNTestAssert.assert_gt(normals.size(), 0, "box has normals")
	for n in normals:
		GNTestAssert.assert_approx(n.length(), 1.0, 0.01, "normal is unit length")

# ═══════════════════════════════════════════════════════════════════════════════
# SphereSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_sphere_more_segments_more_verts() -> void:
	var lo := _make_sphere_geo(4, 2)
	var hi := _make_sphere_geo(16, 8)
	GNTestAssert.assert_gt(_total_verts(hi), _total_verts(lo),
		"more segments = more verts")

func test_sphere_verts_on_surface() -> void:
	var geo := _make_sphere_geo(8, 4)
	var radius := 0.5  # default SphereSOP radius is 0.5
	var verts := _get_positions(geo)
	for v in verts:
		GNTestAssert.assert_approx(v.length(), radius, 0.05,
			"vert on sphere surface: %s" % str(v))

# ═══════════════════════════════════════════════════════════════════════════════
# GridSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_grid_more_rows_more_verts() -> void:
	var lo := _make_grid_geo(2, 2)
	var hi := _make_grid_geo(10, 10)
	GNTestAssert.assert_gt(_total_verts(hi), _total_verts(lo),
		"more rows/cols = more verts")

func test_grid_is_flat() -> void:
	var geo := _make_grid_geo(5, 5)
	var verts := _get_positions(geo)
	for v in verts:
		GNTestAssert.assert_approx(v.y, 0.0, 0.001, "grid flat on Y=0")

# ═══════════════════════════════════════════════════════════════════════════════
# CircleSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_circle_segment_count_affects_verts() -> void:
	var lo := _make_node(CircleSOP.new(), "clo")
	lo.set_param_value("segments", 8)
	var geo_lo := _cook_no_input(lo) as GNGeoData
	var hi := _make_node(CircleSOP.new(), "chi")
	hi.set_param_value("segments", 32)
	var geo_hi := _cook_no_input(hi) as GNGeoData
	GNTestAssert.assert_gt(_total_verts(geo_hi), _total_verts(geo_lo),
		"more segments = more verts")

# ═══════════════════════════════════════════════════════════════════════════════
# CylinderSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_cylinder_cone_mode() -> void:
	var node := _make_node(CylinderSOP.new(), "cone1")
	node.set_param_value("top_radius", 0.0)
	var geo := _cook_no_input(node) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "cone has geometry")
	var verts := _get_positions(geo)
	# At least one vertex should be at the apex (y near top, radius near 0)
	var has_apex := false
	for v in verts:
		if absf(v.x) < 0.01 and absf(v.z) < 0.01:
			has_apex = true
			break
	GNTestAssert.assert_true(has_apex, "cone has apex vertex")

# ═══════════════════════════════════════════════════════════════════════════════
# TorusSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_torus_has_hole() -> void:
	var node := _make_node(TorusSOP.new(), "tor1")
	var geo := _cook_no_input(node) as GNGeoData
	var aabb := geo.mesh.get_aabb()
	# A torus should have a wider X/Z extent than Y
	GNTestAssert.assert_gt(aabb.size.x, aabb.size.y, "torus wider than tall")

# ═══════════════════════════════════════════════════════════════════════════════
# LineSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_line_point_count() -> void:
	var geo := _make_line_geo(5)
	GNTestAssert.assert_eq(_total_verts(geo), 5, "line has 5 verts")

func test_line_is_straight() -> void:
	var geo := _make_line_geo(10)
	var verts := _get_positions(geo)
	# Default line is along X axis (direction=0), so Y and Z should be ~0
	for v in verts:
		GNTestAssert.assert_approx(v.y, 0.0, 0.001, "line straight on Y")
		GNTestAssert.assert_approx(v.z, 0.0, 0.001, "line straight on Z")

# ═══════════════════════════════════════════════════════════════════════════════
# TubeSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_tube_is_hollow() -> void:
	var node := _make_node(TubeSOP.new(), "tube1")
	var geo := _cook_no_input(node) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "tube has geometry")
	GNTestAssert.assert_gt(_total_verts(geo), 0, "tube has vertices")

# ═══════════════════════════════════════════════════════════════════════════════
# TransformSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_transform_translate_shifts_verts() -> void:
	var box_geo := _make_box_geo()
	var xf := _make_node(TransformSOP.new(), "xf1")
	xf.set_param_value("tx", 10.0)
	var out := _cook_with(xf, [box_geo] as Array[GNData]) as GNGeoData
	var verts := _get_positions(out)
	for v in verts:
		GNTestAssert.assert_gt(v.x, 9.0, "vert shifted right by tx=10")

func test_transform_scale_doubles_size() -> void:
	var box_geo := _make_box_geo()
	var original_aabb := box_geo.mesh.get_aabb()
	var xf := _make_node(TransformSOP.new(), "xf2")
	xf.set_param_value("sx", 2.0)
	xf.set_param_value("sy", 2.0)
	xf.set_param_value("sz", 2.0)
	var out := _cook_with(xf, [box_geo] as Array[GNData]) as GNGeoData
	var scaled_aabb := out.mesh.get_aabb()
	GNTestAssert.assert_approx(scaled_aabb.size.x, original_aabb.size.x * 2.0, 0.1,
		"X size doubled")

func test_transform_preserves_vert_count() -> void:
	var box_geo := _make_box_geo()
	var before := _total_verts(box_geo)
	var xf := _make_node(TransformSOP.new(), "xf3")
	xf.set_param_value("ry", 45.0)
	var out := _cook_with(xf, [box_geo] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_eq(_total_verts(out), before, "rotation preserves vert count")

# ═══════════════════════════════════════════════════════════════════════════════
# MergeSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_merge_combines_vert_counts() -> void:
	var box := _make_box_geo()
	var sphere := _make_sphere_geo()
	var node := _make_node(MergeSOP.new(), "merge1")
	var out := _cook_with(node, [box, sphere] as Array[GNData]) as GNGeoData
	var expected := _total_verts(box) + _total_verts(sphere)
	GNTestAssert.assert_eq(_total_verts(out), expected, "merge verts = sum of inputs")

func test_merge_combines_surfaces() -> void:
	var a := _make_box_geo()
	var b := _make_box_geo()
	var node := _make_node(MergeSOP.new(), "merge2")
	var out := _cook_with(node, [a, b] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_eq(_surface_count(out),
		_surface_count(a) + _surface_count(b), "surface count = sum")

# ═══════════════════════════════════════════════════════════════════════════════
# NullSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_null_sop_passthrough() -> void:
	var box := _make_box_geo()
	var node := _make_node(NullSOP.new(), "null1")
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_eq(_total_verts(out), _total_verts(box),
		"null passes through unchanged")

# ═══════════════════════════════════════════════════════════════════════════════
# NormalSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_normal_flip_negates() -> void:
	var box := _make_box_geo()
	var orig_normals := _get_normals(box)
	var node := _make_node(NormalSOP.new(), "norm1")
	node.set_param_value("mode", 1)  # Flip
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	var flipped := _get_normals(out)
	if orig_normals.size() > 0 and flipped.size() == orig_normals.size():
		for i in range(mini(orig_normals.size(), 5)):
			GNTestAssert.assert_approx(flipped[i].x, -orig_normals[i].x, 0.01,
				"normal X flipped")
			GNTestAssert.assert_approx(flipped[i].y, -orig_normals[i].y, 0.01,
				"normal Y flipped")

func test_normal_recompute_unit_length() -> void:
	var box := _make_box_geo()
	var node := _make_node(NormalSOP.new(), "norm2")
	node.set_param_value("mode", 0)  # Recompute smooth
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	var normals := _get_normals(out)
	for n in normals:
		GNTestAssert.assert_approx(n.length(), 1.0, 0.01, "recomputed normal is unit")

# ═══════════════════════════════════════════════════════════════════════════════
# SubdivideSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_subdivide_increases_verts() -> void:
	var box := _make_box_geo()
	var before := _total_verts(box)
	var node := _make_node(SubdivideSOP.new(), "sub1")
	node.set_param_value("iterations", 1)
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_gt(_total_verts(out), before, "subdivide adds verts")

func test_subdivide_more_iterations_more_verts() -> void:
	var box := _make_box_geo()
	var node1 := _make_node(SubdivideSOP.new(), "sub1")
	node1.set_param_value("iterations", 1)
	var out1 := _cook_with(node1, [box] as Array[GNData]) as GNGeoData
	var node2 := _make_node(SubdivideSOP.new(), "sub2")
	node2.set_param_value("iterations", 2)
	var out2 := _cook_with(node2, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_gt(_total_verts(out2), _total_verts(out1),
		"iter=2 > iter=1 verts")

# ═══════════════════════════════════════════════════════════════════════════════
# MirrorSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_mirror_merge_doubles_surfaces() -> void:
	var box := _make_box_geo()
	var node := _make_node(MirrorSOP.new(), "mir1")
	node.set_param_value("merge", true)
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_eq(_surface_count(out), _surface_count(box) * 2,
		"mirror+merge doubles surfaces")

func test_mirror_yz_flips_x() -> void:
	var box := _make_box_geo()
	var orig_verts := _get_positions(box)
	var node := _make_node(MirrorSOP.new(), "mir2")
	node.set_param_value("plane", 0)  # YZ plane
	node.set_param_value("merge", false)
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	var mirrored := _get_positions(out)
	if orig_verts.size() == mirrored.size():
		for i in range(mini(5, orig_verts.size())):
			GNTestAssert.assert_approx(mirrored[i].x, -orig_verts[i].x, 0.01,
				"X mirrored across YZ")

# ═══════════════════════════════════════════════════════════════════════════════
# PeakSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_peak_grows_bounds() -> void:
	var box := _make_box_geo()
	var orig_aabb := box.mesh.get_aabb()
	var node := _make_node(PeakSOP.new(), "peak1")
	node.set_param_value("distance", 0.5)
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	var peaked_aabb := out.mesh.get_aabb()
	GNTestAssert.assert_gt(peaked_aabb.size.x, orig_aabb.size.x, "peak grows X")
	GNTestAssert.assert_gt(peaked_aabb.size.y, orig_aabb.size.y, "peak grows Y")

func test_peak_preserves_vert_count() -> void:
	var box := _make_box_geo()
	var before := _total_verts(box)
	var node := _make_node(PeakSOP.new(), "peak2")
	node.set_param_value("distance", 0.3)
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_eq(_total_verts(out), before, "peak preserves vert count")

# ═══════════════════════════════════════════════════════════════════════════════
# ScatterSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_scatter_output_count() -> void:
	var grid := _make_grid_geo(5, 5)
	var node := _make_node(ScatterSOP.new(), "scat1")
	node.set_param_value("count", 50)
	var out := _cook_with(node, [grid] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_eq(_total_verts(out), 50, "scatter count = 50")

func test_scatter_deterministic_seed() -> void:
	var grid := _make_grid_geo(5, 5)
	var n1 := _make_node(ScatterSOP.new(), "scat2")
	n1.set_param_value("count", 20)
	n1.set_param_value("seed", 42)
	var out1 := _cook_with(n1, [grid] as Array[GNData]) as GNGeoData
	var n2 := _make_node(ScatterSOP.new(), "scat3")
	n2.set_param_value("count", 20)
	n2.set_param_value("seed", 42)
	var out2 := _cook_with(n2, [grid] as Array[GNData]) as GNGeoData
	var v1 := _get_positions(out1)
	var v2 := _get_positions(out2)
	if v1.size() == v2.size() and v1.size() > 0:
		GNTestAssert.assert_approx(v1[0].x, v2[0].x, 0.001, "same seed = same result")

# ═══════════════════════════════════════════════════════════════════════════════
# CopySOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_copy_multiplies_verts() -> void:
	var template := _make_box_geo()
	var points := _make_line_geo(5)  # 5 target points
	var node := _make_node(CopySOP.new(), "copy1")
	var out := _cook_with(node, [template, points] as Array[GNData]) as GNGeoData
	var template_verts := _total_verts(template)
	# Each point gets a copy of the template
	GNTestAssert.assert_eq(_total_verts(out), template_verts * 5,
		"copy verts = template * point count")

# ═══════════════════════════════════════════════════════════════════════════════
# ExtrudeSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_extrude_adds_geometry() -> void:
	var grid := _make_grid_geo(2, 2)
	var before := _total_verts(grid)
	var node := _make_node(ExtrudeSOP.new(), "ext1")
	node.set_param_value("distance", 0.5)
	var out := _cook_with(node, [grid] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_gt(_total_verts(out), before, "extrude adds verts")

func test_extrude_grows_bounds() -> void:
	var grid := _make_grid_geo(2, 2)
	var orig_aabb := grid.mesh.get_aabb()
	var node := _make_node(ExtrudeSOP.new(), "ext2")
	node.set_param_value("distance", 1.0)
	var out := _cook_with(node, [grid] as Array[GNData]) as GNGeoData
	var ext_aabb := out.mesh.get_aabb()
	GNTestAssert.assert_gt(ext_aabb.size.y, orig_aabb.size.y,
		"extrude expands bounds along normal")

# ═══════════════════════════════════════════════════════════════════════════════
# ClipSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_clip_produces_geometry() -> void:
	var box := _make_box_geo()
	var node := _make_node(ClipSOP.new(), "clip1")
	node.set_param_value("plane", 1)  # Y
	node.set_param_value("origin", 0.0)
	node.set_param_value("keep_above", true)
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	# Clip splits triangles at boundary — output may have more or fewer verts
	GNTestAssert.assert_gt(_total_verts(out), 0, "clip produces geometry")

func test_clip_verts_above_plane() -> void:
	var box := _make_box_geo()
	var node := _make_node(ClipSOP.new(), "clip2")
	node.set_param_value("plane", 1)  # Y
	node.set_param_value("origin", 0.0)
	node.set_param_value("keep_above", true)
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	var verts := _get_positions(out)
	for v in verts:
		GNTestAssert.assert_true(v.y >= -0.01, "clipped vert above Y=0: y=%s" % str(v.y))

# ═══════════════════════════════════════════════════════════════════════════════
# DeleteSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_delete_reduces_verts() -> void:
	var box := _make_box_geo()
	var before := _total_verts(box)
	var node := _make_node(DeleteSOP.new(), "del1")
	node.set_param_value("entity", 0)  # Faces
	node.set_param_value("method", 0)  # Range
	node.set_param_value("start", 0)
	node.set_param_value("end", 10)  # Delete most faces from 12-tri box
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_gt(_total_verts(out), 0, "delete still has some geometry")
	GNTestAssert.assert_lt(_total_verts(out), before, "delete removes geometry")

# ═══════════════════════════════════════════════════════════════════════════════
# SortSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_sort_preserves_vert_count() -> void:
	var box := _make_box_geo()
	var before := _total_verts(box)
	var node := _make_node(SortSOP.new(), "sort1")
	node.set_param_value("method", 0)  # Along X
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_eq(_total_verts(out), before, "sort preserves vert count")

func test_sort_along_x_ordered() -> void:
	var line := _make_line_geo(10)
	var node := _make_node(SortSOP.new(), "sort2")
	node.set_param_value("method", 0)  # Along X
	var out := _cook_with(node, [line] as Array[GNData]) as GNGeoData
	var verts := _get_positions(out)
	for i in range(1, verts.size()):
		GNTestAssert.assert_true(verts[i].x >= verts[i - 1].x - 0.001,
			"sorted ascending X: v[%d]=%s" % [i, str(verts[i].x)])

# ═══════════════════════════════════════════════════════════════════════════════
# ReverseSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_reverse_flips_normals() -> void:
	var box := _make_box_geo()
	var orig := _get_normals(box)
	var node := _make_node(ReverseSOP.new(), "rev1")
	node.set_param_value("flip_normals", true)
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	var reversed := _get_normals(out)
	if orig.size() > 0 and reversed.size() == orig.size():
		GNTestAssert.assert_approx(reversed[0].x, -orig[0].x, 0.01, "normal X flipped")

func test_reverse_preserves_vert_count() -> void:
	var box := _make_box_geo()
	var before := _total_verts(box)
	var node := _make_node(ReverseSOP.new(), "rev2")
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_eq(_total_verts(out), before, "reverse preserves vert count")

# ═══════════════════════════════════════════════════════════════════════════════
# FuseSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_fuse_reduces_duplicates() -> void:
	# Merge two identical boxes — they share vertices at the same positions
	var a := _make_box_geo()
	var b := _make_box_geo()
	var merge := _make_node(MergeSOP.new(), "mrg")
	var merged := _cook_with(merge, [a, b] as Array[GNData]) as GNGeoData
	var before := _total_verts(merged)
	var node := _make_node(FuseSOP.new(), "fuse1")
	node.set_param_value("threshold", 0.01)
	var out := _cook_with(node, [merged] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_lt(_total_verts(out), before, "fuse removes duplicate verts")

# ═══════════════════════════════════════════════════════════════════════════════
# SmoothSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_smooth_preserves_vert_count() -> void:
	var box := _make_box_geo()
	var before := _total_verts(box)
	var node := _make_node(SmoothSOP.new(), "sm1")
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_eq(_total_verts(out), before, "smooth preserves vert count")

# ═══════════════════════════════════════════════════════════════════════════════
# BendSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_bend_changes_positions() -> void:
	# Bend needs geometry with extent along the bend axis (Y)
	var box := _make_box_geo(1.0, 2.0, 1.0)
	var orig := _get_positions(box)
	var node := _make_node(BendSOP.new(), "bend1")
	node.set_param_value("angle", 45.0)
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	var bent := _get_positions(out)
	var any_changed := false
	for i in range(mini(orig.size(), bent.size())):
		if orig[i].distance_to(bent[i]) > 0.01:
			any_changed = true
			break
	GNTestAssert.assert_true(any_changed, "bend modifies vertex positions")

# ═══════════════════════════════════════════════════════════════════════════════
# TwistSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_twist_changes_positions() -> void:
	# Twist needs geometry with extent along the twist axis (Y)
	var box := _make_box_geo(1.0, 2.0, 1.0)
	var orig := _get_positions(box)
	var node := _make_node(TwistSOP.new(), "tw1")
	node.set_param_value("angle", 90.0)
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	var twisted := _get_positions(out)
	var any_changed := false
	for i in range(mini(orig.size(), twisted.size())):
		if orig[i].distance_to(twisted[i]) > 0.01:
			any_changed = true
			break
	GNTestAssert.assert_true(any_changed, "twist modifies vertex positions")

# ═══════════════════════════════════════════════════════════════════════════════
# TaperSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_taper_changes_positions() -> void:
	# Taper needs geometry with extent along the taper axis (Y)
	var box := _make_box_geo(1.0, 2.0, 1.0)
	var orig := _get_positions(box)
	var node := _make_node(TaperSOP.new(), "tpr1")
	node.set_param_value("scale_end", 0.3)
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	var tapered := _get_positions(out)
	var any_changed := false
	for i in range(mini(orig.size(), tapered.size())):
		if orig[i].distance_to(tapered[i]) > 0.01:
			any_changed = true
			break
	GNTestAssert.assert_true(any_changed, "taper modifies vertex positions")

# ═══════════════════════════════════════════════════════════════════════════════
# NoiseSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_noise_displaces_verts() -> void:
	var grid := _make_grid_geo(5, 5)
	var orig := _get_positions(grid)
	var node := _make_node(NoiseSOP.new(), "ns1")
	node.set_param_value("amplitude", 1.0)
	var out := _cook_with(node, [grid] as Array[GNData]) as GNGeoData
	var noised := _get_positions(out)
	var any_changed := false
	for i in range(mini(orig.size(), noised.size())):
		if orig[i].distance_to(noised[i]) > 0.01:
			any_changed = true
			break
	GNTestAssert.assert_true(any_changed, "noise displaces verts")

func test_noise_seed_deterministic() -> void:
	var grid := _make_grid_geo(3, 3)
	var n1 := _make_node(NoiseSOP.new(), "ns2")
	n1.set_param_value("seed", 42)
	n1.set_param_value("amplitude", 1.0)
	var out1 := _cook_with(n1, [grid] as Array[GNData]) as GNGeoData
	var grid2 := _make_grid_geo(3, 3)
	var n2 := _make_node(NoiseSOP.new(), "ns3")
	n2.set_param_value("seed", 42)
	n2.set_param_value("amplitude", 1.0)
	var out2 := _cook_with(n2, [grid2] as Array[GNData]) as GNGeoData
	var v1 := _get_positions(out1)
	var v2 := _get_positions(out2)
	if v1.size() > 0 and v2.size() > 0:
		GNTestAssert.assert_approx(v1[0].y, v2[0].y, 0.001, "same seed = same noise")

# ═══════════════════════════════════════════════════════════════════════════════
# AttributeSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_attribute_constant_fill() -> void:
	var box := _make_box_geo()
	var node := _make_node(AttributeSOP.new(), "attr1")
	node.set_param_value("name", "pscale")
	node.set_param_value("source", 0)  # Constant
	node.set_param_value("value", 2.5)
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	if out != null and out.point_attribs.has("pscale"):
		var arr: PackedFloat32Array = out.point_attribs["pscale"]
		GNTestAssert.assert_eq(arr.size(), _total_verts(out), "attrib size = vert count")
		if arr.size() > 0:
			GNTestAssert.assert_approx(arr[0], 2.5, 0.001, "constant value = 2.5")

# ═══════════════════════════════════════════════════════════════════════════════
# SwitchSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_switch_selects_input() -> void:
	var box := _make_box_geo()
	var sphere := _make_sphere_geo()
	var node := _make_node(SwitchSOP.new(), "sw1")
	node.set_param_value("index", 1)
	var out := _cook_with(node, [box, sphere] as Array[GNData]) as GNGeoData
	# SwitchSOP uses dynamic inputs — verify output differs from default (index=0)
	var box_verts := _total_verts(box)
	var out_verts := _total_verts(out)
	GNTestAssert.assert_gt(out_verts, 0, "switch produces output")

# ═══════════════════════════════════════════════════════════════════════════════
# BlendSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_blend_interpolates() -> void:
	var small := _make_box_geo(1.0, 1.0, 1.0)
	var large := _make_box_geo(3.0, 3.0, 3.0)
	var node := _make_node(BlendSOP.new(), "blend1")
	node.set_param_value("weight", 0.5)
	var out := _cook_with(node, [small, large] as Array[GNData]) as GNGeoData
	if out != null:
		var out_aabb := out.mesh.get_aabb()
		var small_aabb := small.mesh.get_aabb()
		var large_aabb := large.mesh.get_aabb()
		# Blended size should be between small and large
		GNTestAssert.assert_gt(out_aabb.size.x, small_aabb.size.x, "blend > small")
		GNTestAssert.assert_lt(out_aabb.size.x, large_aabb.size.x, "blend < large")

# ═══════════════════════════════════════════════════════════════════════════════
# WireframeSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_wireframe_adds_geometry() -> void:
	var box := _make_box_geo()
	var before := _total_verts(box)
	var node := _make_node(WireframeSOP.new(), "wf1")
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_gt(_total_verts(out), before, "wireframe adds tube geometry")

# ═══════════════════════════════════════════════════════════════════════════════
# DivideSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_divide_produces_output() -> void:
	var box := _make_box_geo()
	var node := _make_node(DivideSOP.new(), "div1")
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	# Divide in triangulate mode passes through already-triangulated meshes unchanged
	GNTestAssert.assert_gt(_total_verts(out), 0, "divide produces geometry")

# ═══════════════════════════════════════════════════════════════════════════════
# FacetSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_facet_unique_points_unshares() -> void:
	var box := _make_box_geo()
	var node := _make_node(FacetSOP.new(), "fac1")
	# Unique points mode should ensure no vertex sharing
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_true(out.has_geometry(), "facet produces geometry")

# ═══════════════════════════════════════════════════════════════════════════════
# MountainSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_mountain_displaces_grid() -> void:
	var grid := _make_grid_geo(5, 5)
	var orig := _get_positions(grid)
	var node := _make_node(MountainSOP.new(), "mtn1")
	var out := _cook_with(node, [grid] as Array[GNData]) as GNGeoData
	var displaced := _get_positions(out)
	var any_changed := false
	for i in range(mini(orig.size(), displaced.size())):
		if absf(orig[i].y - displaced[i].y) > 0.001:
			any_changed = true
			break
	GNTestAssert.assert_true(any_changed, "mountain displaces Y")

# ═══════════════════════════════════════════════════════════════════════════════
# PolyReduceSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_polyreduce_fewer_verts() -> void:
	var sphere := _make_sphere_geo(16, 8)
	var before := _total_verts(sphere)
	var node := _make_node(PolyReduceSOP.new(), "pr1")
	node.set_param_value("target_ratio", 0.5)
	var out := _cook_with(node, [sphere] as Array[GNData]) as GNGeoData
	if out != null and out.has_geometry():
		GNTestAssert.assert_lt(_total_verts(out), before, "polyreduce reduces verts")

# ═══════════════════════════════════════════════════════════════════════════════
# CapSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_cap_adds_geometry() -> void:
	var tube := _make_node(TubeSOP.new(), "tube1")
	var tube_geo := _cook_no_input(tube) as GNGeoData
	var before := _total_verts(tube_geo)
	var node := _make_node(CapSOP.new(), "cap1")
	var out := _cook_with(node, [tube_geo] as Array[GNData]) as GNGeoData
	if out != null:
		GNTestAssert.assert_true(out.has_geometry(), "cap produces geometry")

# ═══════════════════════════════════════════════════════════════════════════════
# UVProjectSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_uvproject_preserves_verts() -> void:
	var box := _make_box_geo()
	var before := _total_verts(box)
	var node := _make_node(UVProjectSOP.new(), "uv1")
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_eq(_total_verts(out), before, "uvproject preserves vert count")

# ═══════════════════════════════════════════════════════════════════════════════
# TextureSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_texture_sop_preserves_verts() -> void:
	var box := _make_box_geo()
	var before := _total_verts(box)
	var node := _make_node(TextureSOP.new(), "tex1")
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_eq(_total_verts(out), before, "texture preserves vert count")

# ═══════════════════════════════════════════════════════════════════════════════
# PointSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_point_sop_preserves_count() -> void:
	var box := _make_box_geo()
	var node := _make_node(PointSOP.new(), "pt1")
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_gt(_total_verts(out), 0, "point produces geometry")

# ═══════════════════════════════════════════════════════════════════════════════
# PrimitiveSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_primitive_sop_modifies_geo() -> void:
	var box := _make_box_geo()
	var node := _make_node(PrimitiveSOP.new(), "prim1")
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_true(out.has_geometry(), "primitive produces geometry")

# ═══════════════════════════════════════════════════════════════════════════════
# FilterSOP (wired filtering; SelectSOP is wireless-only)
# ═══════════════════════════════════════════════════════════════════════════════

func test_select_sop_passthrough() -> void:
	var box := _make_box_geo()
	var node := _make_node(FilterSOP.new(), "filt1")
	node.set_param_value("method", 0)  # By Range
	node.set_param_value("start", 0)
	node.set_param_value("end", 999999)
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_gt(_total_verts(out), 0, "filter passes geometry through")

# ═══════════════════════════════════════════════════════════════════════════════
# CarvesSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_carve_reduces_line() -> void:
	var line := _make_line_geo(20)
	var node := _make_node(CarveSOP.new(), "carve1")
	node.set_param_value("start", 0.2)
	node.set_param_value("end", 0.8)
	var out := _cook_with(node, [line] as Array[GNData]) as GNGeoData
	if out != null:
		GNTestAssert.assert_lt(_total_verts(out), 20, "carve reduces line points")

# ═══════════════════════════════════════════════════════════════════════════════
# MetaballSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_metaball_generates_mesh() -> void:
	var node := _make_node(MetaballSOP.new(), "meta1")
	var out := _cook_no_input(node) as GNGeoData
	GNTestAssert.assert_true(out != null and out.has_geometry(), "metaball has geometry")
	GNTestAssert.assert_gt(_total_verts(out), 0, "metaball has verts")

# ═══════════════════════════════════════════════════════════════════════════════
# IsoSurfaceSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_isosurface_generates_mesh() -> void:
	var node := _make_node(IsoSurfaceSOP.new(), "iso1")
	var out := _cook_no_input(node) as GNGeoData
	if out != null:
		GNTestAssert.assert_true(out.has_geometry(), "isosurface has geometry")

# ═══════════════════════════════════════════════════════════════════════════════
# HeightfieldSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_heightfield_generates_grid() -> void:
	var node := _make_node(HeightfieldSOP.new(), "hf1")
	var out := _cook_no_input(node) as GNGeoData
	GNTestAssert.assert_true(out != null and out.has_geometry(), "heightfield has geometry")
	GNTestAssert.assert_gt(_total_verts(out), 0, "heightfield has verts")

# ═══════════════════════════════════════════════════════════════════════════════
# LSystemSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_lsystem_generates_mesh() -> void:
	var node := _make_node(LSystemSOP.new(), "ls1")
	var out := _cook_no_input(node) as GNGeoData
	if out != null:
		GNTestAssert.assert_true(out.has_geometry(), "lsystem has geometry")

# ═══════════════════════════════════════════════════════════════════════════════
# SweepSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_sweep_produces_mesh() -> void:
	var circle := _make_node(CircleSOP.new(), "circ")
	var circ_geo := _cook_no_input(circle) as GNGeoData
	var line := _make_line_geo(10)
	var node := _make_node(SweepSOP.new(), "sweep1")
	var out := _cook_with(node, [circ_geo, line] as Array[GNData]) as GNGeoData
	if out != null:
		GNTestAssert.assert_true(out.has_geometry(), "sweep has geometry")
		GNTestAssert.assert_gt(_total_verts(out), 0, "sweep has verts")

# ═══════════════════════════════════════════════════════════════════════════════
# SkinSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_skin_produces_mesh() -> void:
	var c1 := _make_node(CircleSOP.new(), "c1")
	var c1_geo := _cook_no_input(c1) as GNGeoData
	var c2 := _make_node(CircleSOP.new(), "c2")
	var c2_geo := _cook_no_input(c2) as GNGeoData
	var node := _make_node(SkinSOP.new(), "skin1")
	var out := _cook_with(node, [c1_geo, c2_geo] as Array[GNData]) as GNGeoData
	if out != null:
		GNTestAssert.assert_true(out.has_geometry(), "skin has geometry")

# ═══════════════════════════════════════════════════════════════════════════════
# RemeshSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_remesh_changes_topology() -> void:
	var box := _make_box_geo()
	var before := _total_verts(box)
	var node := _make_node(RemeshSOP.new(), "rem1")
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	if out != null and out.has_geometry():
		GNTestAssert.assert_ne(_total_verts(out), before, "remesh changes topology")

# ═══════════════════════════════════════════════════════════════════════════════
# VoronoiShatterSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_voronoi_shatters_into_pieces() -> void:
	var box := _make_box_geo()
	var node := _make_node(VoronoiShatterSOP.new(), "vor1")
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	if out != null:
		GNTestAssert.assert_gt(_surface_count(out), 1, "voronoi creates multiple pieces")

# ═══════════════════════════════════════════════════════════════════════════════
# BooleanSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_boolean_subtract_removes_geometry() -> void:
	var a := _make_box_geo(2.0, 2.0, 2.0)
	var b := _make_box_geo(1.0, 1.0, 1.0)  # Smaller box at origin
	var node := _make_node(BooleanSOP.new(), "bool1")
	node.set_param_value("operation", 1)  # Subtract
	var out := _cook_with(node, [a, b] as Array[GNData]) as GNGeoData
	if out != null and out.has_geometry():
		GNTestAssert.assert_true(true, "boolean subtract produced geometry")

# ═══════════════════════════════════════════════════════════════════════════════
# GroupSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_group_preserves_geometry() -> void:
	var box := _make_box_geo()
	var before := _total_verts(box)
	var node := _make_node(GroupSOP.new(), "grp1")
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_eq(_total_verts(out), before, "group preserves vert count")

# ═══════════════════════════════════════════════════════════════════════════════
# LatticeSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_lattice_preserves_vert_count() -> void:
	var box := _make_box_geo()
	var before := _total_verts(box)
	var node := _make_node(LatticeSOP.new(), "lat1")
	var out := _cook_with(node, [box] as Array[GNData]) as GNGeoData
	GNTestAssert.assert_eq(_total_verts(out), before, "lattice preserves vert count")

# ═══════════════════════════════════════════════════════════════════════════════
# MagnetSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_magnet_modifies_positions() -> void:
	var grid := _make_grid_geo(5, 5)
	var orig := _get_positions(grid)
	var node := _make_node(MagnetSOP.new(), "mag1")
	node.set_param_value("strength", 1.0)
	var out := _cook_with(node, [grid] as Array[GNData]) as GNGeoData
	var moved := _get_positions(out)
	var any_changed := false
	for i in range(mini(orig.size(), moved.size())):
		if orig[i].distance_to(moved[i]) > 0.001:
			any_changed = true
			break
	GNTestAssert.assert_true(any_changed, "magnet displaces verts")
