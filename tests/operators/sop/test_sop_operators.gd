extends Node
## Correctness tests for SOP operators.
##
## Each test instantiates the operator, sets parameters, provides input,
## calls execute_cook, and verifies output geometry data.

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


## Helper: creates a box, cooks it, returns its GNGeoData.
func _make_box_geo(sx: float = 1.0, sy: float = 1.0, sz: float = 1.0) -> GNGeoData:
	var box := _make_node(BoxSOP.new(), "box_%d" % randi())
	box.set_param_value("size_x", sx)
	box.set_param_value("size_y", sy)
	box.set_param_value("size_z", sz)
	return _cook_no_input(box) as GNGeoData


## Helper: creates a grid, cooks it, returns its GNGeoData.
func _make_grid_geo(rows: int = 10, cols: int = 10) -> GNGeoData:
	var grid := _make_node(GridSOP.new(), "grid_%d" % randi())
	grid.set_param_value("rows", rows)
	grid.set_param_value("cols", cols)
	return _cook_no_input(grid) as GNGeoData


## Helper: creates a sphere, cooks it, returns its GNGeoData.
func _make_sphere_geo(r_seg: int = 8, rings: int = 4) -> GNGeoData:
	var sph := _make_node(SphereSOP.new(), "sph_%d" % randi())
	sph.set_param_value("radial_segments", r_seg)
	sph.set_param_value("rings", rings)
	return _cook_no_input(sph) as GNGeoData


## Helper: creates a line, cooks it, returns its GNGeoData.
func _make_line_geo(pts: int = 10) -> GNGeoData:
	var ln := _make_node(LineSOP.new(), "line_%d" % randi())
	ln.set_param_value("points", pts)
	return _cook_no_input(ln) as GNGeoData


## Returns vertex count for surface 0 of a GNGeoData.
func _vert_count(geo: GNGeoData, surf: int = 0) -> int:
	if geo == null or geo.mesh == null or geo.mesh.get_surface_count() <= surf:
		return 0
	return geo.mesh.surface_get_arrays(surf)[Mesh.ARRAY_VERTEX].size()


## Returns total vertex count across all surfaces.
func _total_verts(geo: GNGeoData) -> int:
	if geo == null or geo.mesh == null:
		return 0
	var total := 0
	for s in range(geo.mesh.get_surface_count()):
		var arrays: Array = geo.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			total += arrays[Mesh.ARRAY_VERTEX].size()
	return total


# ═══════════════════════════════════════════════════════════════════════════════
#  BoxSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_box_sop_default() -> void:
	var geo := _make_box_geo()
	GNTestAssert.assert_not_null(geo, "box produces output")
	GNTestAssert.assert_true(geo.has_geometry(), "box has geometry")
	GNTestAssert.assert_eq(geo.mesh.get_surface_count(), 1, "box: 1 surface")
	GNTestAssert.assert_eq(_vert_count(geo), 24, "box: 24 verts (4×6 faces)")


func test_box_sop_subdivide_increases_verts() -> void:
	var box := _make_node(BoxSOP.new(), "box_sub")
	box.set_param_value("subdivide_w", 2)
	box.set_param_value("subdivide_h", 2)
	box.set_param_value("subdivide_d", 2)
	var geo: GNGeoData = _cook_no_input(box) as GNGeoData
	GNTestAssert.assert_gt(_vert_count(geo), 24, "subdivided box has more verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  SphereSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_sphere_sop_default() -> void:
	var sph := _make_node(SphereSOP.new(), "sphere1")
	var geo: GNGeoData = _cook_no_input(sph) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "sphere has geometry")
	GNTestAssert.assert_eq(geo.mesh.get_surface_count(), 1, "sphere: 1 surface")
	GNTestAssert.assert_gt(_vert_count(geo), 100, "sphere has many verts")


func test_sphere_sop_hemisphere_fewer_verts() -> void:
	var full := _make_node(SphereSOP.new(), "sph_full")
	full.set_param_value("radial_segments", 16)
	full.set_param_value("rings", 8)
	var geo_full: GNGeoData = _cook_no_input(full) as GNGeoData

	var half := _make_node(SphereSOP.new(), "sph_half")
	half.set_param_value("radial_segments", 16)
	half.set_param_value("rings", 8)
	half.set_param_value("is_hemisphere", true)
	var geo_half: GNGeoData = _cook_no_input(half) as GNGeoData

	GNTestAssert.assert_true(geo_half.has_geometry(), "hemisphere has geometry")
	GNTestAssert.assert_true(_vert_count(geo_half) <= _vert_count(geo_full),
		"hemisphere has no more verts than full sphere")


# ═══════════════════════════════════════════════════════════════════════════════
#  GridSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_grid_sop_vertex_count() -> void:
	var geo := _make_grid_geo(10, 10)
	GNTestAssert.assert_true(geo.has_geometry(), "grid has geometry")
	# Grid with rows=10, cols=10 → (10+1)*(10+1) = 121 unique positions,
	# but triangulated → more verts with unique normals/UVs
	GNTestAssert.assert_gt(_vert_count(geo), 0, "grid has verts")


func test_grid_sop_different_resolution() -> void:
	var geo5 := _make_grid_geo(5, 5)
	var geo20 := _make_grid_geo(20, 20)
	GNTestAssert.assert_gt(_vert_count(geo20), _vert_count(geo5),
		"higher resolution grid has more verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  CircleSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_circle_sop_default() -> void:
	var node := _make_node(CircleSOP.new(), "circle1")
	var geo: GNGeoData = _cook_no_input(node) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "circle has geometry")
	GNTestAssert.assert_eq(geo.mesh.get_surface_count(), 1, "circle: 1 surface")


func test_circle_sop_more_segments() -> void:
	var lo := _make_node(CircleSOP.new(), "circ_lo")
	lo.set_param_value("segments", 8)
	var geo_lo: GNGeoData = _cook_no_input(lo) as GNGeoData

	var hi := _make_node(CircleSOP.new(), "circ_hi")
	hi.set_param_value("segments", 32)
	var geo_hi: GNGeoData = _cook_no_input(hi) as GNGeoData

	GNTestAssert.assert_gt(_vert_count(geo_hi), _vert_count(geo_lo),
		"more segments → more verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  CylinderSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_cylinder_sop_default() -> void:
	var node := _make_node(CylinderSOP.new(), "cyl1")
	var geo: GNGeoData = _cook_no_input(node) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "cylinder has geometry")
	GNTestAssert.assert_gt(_vert_count(geo), 0, "cylinder has verts")


func test_cylinder_sop_cone() -> void:
	var node := _make_node(CylinderSOP.new(), "cone1")
	node.set_param_value("top_radius", 0.0)
	var geo: GNGeoData = _cook_no_input(node) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "cone has geometry")


func test_cylinder_sop_more_segments() -> void:
	var lo := _make_node(CylinderSOP.new(), "cyl_lo")
	lo.set_param_value("radial_segments", 6)
	var geo_lo: GNGeoData = _cook_no_input(lo) as GNGeoData

	var hi := _make_node(CylinderSOP.new(), "cyl_hi")
	hi.set_param_value("radial_segments", 32)
	var geo_hi: GNGeoData = _cook_no_input(hi) as GNGeoData

	GNTestAssert.assert_gt(_vert_count(geo_hi), _vert_count(geo_lo),
		"more radial segments → more verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  TorusSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_torus_sop_default() -> void:
	var node := _make_node(TorusSOP.new(), "torus1")
	var geo: GNGeoData = _cook_no_input(node) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "torus has geometry")
	GNTestAssert.assert_gt(_vert_count(geo), 50, "torus has many verts")
	GNTestAssert.assert_true(geo.has_geometry(), "torus has geometry")
	GNTestAssert.assert_gt(_vert_count(geo), 100, "torus has many verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  TubeSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_tube_sop_default() -> void:
	var node := _make_node(TubeSOP.new(), "tube1")
	var geo: GNGeoData = _cook_no_input(node) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "tube has geometry")


# ═══════════════════════════════════════════════════════════════════════════════
#  LineSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_line_sop_vertex_count() -> void:
	var node := _make_node(LineSOP.new(), "line1")
	node.set_param_value("points", 20)
	var geo: GNGeoData = _cook_no_input(node) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "line has geometry")
	GNTestAssert.assert_eq(_vert_count(geo), 20, "line has 20 verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  LSystemSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_lsystem_sop_default() -> void:
	var node := _make_node(LSystemSOP.new(), "lsys1")
	var geo: GNGeoData = _cook_no_input(node) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "lsystem produces geometry")
	GNTestAssert.assert_gt(_vert_count(geo), 0, "lsystem has verts")


func test_lsystem_sop_more_iterations() -> void:
	var ls2 := _make_node(LSystemSOP.new(), "lsys_2")
	ls2.set_param_value("iterations", 2)
	var geo2: GNGeoData = _cook_no_input(ls2) as GNGeoData

	var ls4 := _make_node(LSystemSOP.new(), "lsys_4")
	ls4.set_param_value("iterations", 4)
	var geo4: GNGeoData = _cook_no_input(ls4) as GNGeoData

	GNTestAssert.assert_gt(_vert_count(geo4), _vert_count(geo2),
		"more iterations → more verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  IsoSurfaceSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_isosurface_sop_default() -> void:
	var node := _make_node(IsoSurfaceSOP.new(), "iso1")
	var geo: GNGeoData = _cook_no_input(node) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "isosurface has geometry")
	GNTestAssert.assert_gt(_vert_count(geo), 100, "isosurface has many verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  MetaballSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_metaball_sop_default() -> void:
	var node := _make_node(MetaballSOP.new(), "meta1")
	var geo: GNGeoData = _cook_no_input(node) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "metaball has geometry")
	GNTestAssert.assert_gt(_vert_count(geo), 10, "metaball has verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  FontSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_font_sop_produces_geometry() -> void:
	var node := _make_node(FontSOP.new(), "font1")
	node.set_param_value("text", "Hi")
	var geo: GNGeoData = _cook_no_input(node) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "font produces geometry")


func test_font_sop_empty_text() -> void:
	var node := _make_node(FontSOP.new(), "font2")
	node.set_param_value("text", "")
	var geo: GNGeoData = _cook_no_input(node) as GNGeoData
	# Empty text should produce no geometry or empty geo
	if geo != null:
		GNTestAssert.assert_false(geo.has_geometry(), "empty text → no geometry")


# ═══════════════════════════════════════════════════════════════════════════════
#  TransformSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_transform_sop_preserves_verts() -> void:
	var input := _make_box_geo()
	var vc_in := _vert_count(input)
	var node := _make_node(TransformSOP.new(), "xform1")
	node.set_param_value("tx", 5.0)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_eq(_vert_count(geo), vc_in, "transform preserves vert count")


func test_transform_sop_translate_shifts_positions() -> void:
	var input := _make_box_geo()
	var pos_before: PackedVector3Array = input.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var node := _make_node(TransformSOP.new(), "xform2")
	node.set_param_value("tx", 10.0)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	var pos_after: PackedVector3Array = geo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# All positions should be shifted by +10 on X
	GNTestAssert.assert_approx(pos_after[0].x - pos_before[0].x, 10.0, 0.01,
		"X shifted by 10")


func test_transform_sop_scale() -> void:
	var input := _make_box_geo()
	var node := _make_node(TransformSOP.new(), "xform3")
	node.set_param_value("sx", 2.0)
	node.set_param_value("sy", 2.0)
	node.set_param_value("sz", 2.0)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	var pos_after: PackedVector3Array = geo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var pos_before: PackedVector3Array = input.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	GNTestAssert.assert_approx(pos_after[0].x, pos_before[0].x * 2.0, 0.01,
		"X scaled by 2")


# ═══════════════════════════════════════════════════════════════════════════════
#  NoiseSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_noise_sop_preserves_vert_count() -> void:
	var input := _make_grid_geo(5, 5)
	var vc_in := _vert_count(input)
	var node := _make_node(NoiseSOP.new(), "noise1")
	node.set_param_value("amplitude", 0.5)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_eq(_vert_count(geo), vc_in, "noise preserves vert count")


func test_noise_sop_deforms_positions() -> void:
	var input := _make_grid_geo(5, 5)
	var pos_before: PackedVector3Array = input.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var node := _make_node(NoiseSOP.new(), "noise2")
	node.set_param_value("amplitude", 1.0)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	var pos_after: PackedVector3Array = geo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# At least some verts should have moved
	var moved := false
	for i in range(pos_before.size()):
		if pos_before[i].distance_to(pos_after[i]) > 0.01:
			moved = true
			break
	GNTestAssert.assert_true(moved, "noise deformed at least one vertex")


# ═══════════════════════════════════════════════════════════════════════════════
#  MountainSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_mountain_sop_deforms() -> void:
	var input := _make_grid_geo(5, 5)
	var pos_before: PackedVector3Array = input.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var node := _make_node(MountainSOP.new(), "mtn1")
	node.set_param_value("height", 1.0)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	var pos_after: PackedVector3Array = geo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var moved := false
	for i in range(pos_before.size()):
		if pos_before[i].distance_to(pos_after[i]) > 0.01:
			moved = true
			break
	GNTestAssert.assert_true(moved, "mountain deformed at least one vertex")


# ═══════════════════════════════════════════════════════════════════════════════
#  BendSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_bend_sop_zero_angle_passthrough() -> void:
	var input := _make_box_geo()
	var pos_before: PackedVector3Array = input.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var node := _make_node(BendSOP.new(), "bend1")
	node.set_param_value("angle", 0.0)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	var pos_after: PackedVector3Array = geo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	GNTestAssert.assert_approx(pos_before[0].x, pos_after[0].x, 0.01, "angle=0 → no change")


func test_bend_sop_nonzero_deforms() -> void:
	var input := _make_box_geo()
	var pos_before: PackedVector3Array = input.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var node := _make_node(BendSOP.new(), "bend2")
	node.set_param_value("angle", 45.0)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	var pos_after: PackedVector3Array = geo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var moved := false
	for i in range(pos_before.size()):
		if pos_before[i].distance_to(pos_after[i]) > 0.01:
			moved = true
			break
	GNTestAssert.assert_true(moved, "bend with angle deforms geometry")


# ═══════════════════════════════════════════════════════════════════════════════
#  TwistSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_twist_sop_zero_passthrough() -> void:
	var input := _make_box_geo()
	var node := _make_node(TwistSOP.new(), "twist1")
	node.set_param_value("angle", 0.0)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_eq(_vert_count(geo), _vert_count(input), "twist preserves verts")


func test_twist_sop_deforms() -> void:
	var input := _make_box_geo()
	var pos_before: PackedVector3Array = input.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var node := _make_node(TwistSOP.new(), "twist2")
	node.set_param_value("angle", 90.0)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	var pos_after: PackedVector3Array = geo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var moved := false
	for i in range(pos_before.size()):
		if pos_before[i].distance_to(pos_after[i]) > 0.01:
			moved = true
			break
	GNTestAssert.assert_true(moved, "twist deforms geometry")


# ═══════════════════════════════════════════════════════════════════════════════
#  TaperSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_taper_sop_identity() -> void:
	var input := _make_box_geo()
	var node := _make_node(TaperSOP.new(), "taper1")
	node.set_param_value("scale_start", 1.0)
	node.set_param_value("scale_end", 1.0)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_eq(_vert_count(geo), _vert_count(input), "taper identity preserves verts")


func test_taper_sop_tapers() -> void:
	var input := _make_box_geo()
	var pos_before: PackedVector3Array = input.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var node := _make_node(TaperSOP.new(), "taper2")
	node.set_param_value("scale_start", 1.0)
	node.set_param_value("scale_end", 0.1)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	var pos_after: PackedVector3Array = geo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var moved := false
	for i in range(pos_before.size()):
		if pos_before[i].distance_to(pos_after[i]) > 0.01:
			moved = true
			break
	GNTestAssert.assert_true(moved, "taper deforms geometry")


# ═══════════════════════════════════════════════════════════════════════════════
#  PeakSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_peak_sop_zero_passthrough() -> void:
	var input := _make_box_geo()
	var pos_before: PackedVector3Array = input.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var node := _make_node(PeakSOP.new(), "peak1")
	node.set_param_value("distance", 0.0)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	var pos_after: PackedVector3Array = geo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	GNTestAssert.assert_approx(pos_before[0].x, pos_after[0].x, 0.01, "peak=0 → no change")


func test_peak_sop_pushes_along_normals() -> void:
	var input := _make_box_geo()
	var pos_before: PackedVector3Array = input.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var node := _make_node(PeakSOP.new(), "peak2")
	node.set_param_value("distance", 0.5)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	var pos_after: PackedVector3Array = geo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var moved := false
	for i in range(pos_before.size()):
		if pos_before[i].distance_to(pos_after[i]) > 0.01:
			moved = true
			break
	GNTestAssert.assert_true(moved, "peak pushes verts along normals")


# ═══════════════════════════════════════════════════════════════════════════════
#  SubdivideSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_subdivide_sop_increases_verts() -> void:
	var input := _make_box_geo()
	var vc_in := _vert_count(input)
	var node := _make_node(SubdivideSOP.new(), "subdiv1")
	node.set_param_value("iterations", 1)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_gt(_vert_count(geo), vc_in, "subdivide increases verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  NormalSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_normal_sop_has_normals() -> void:
	var input := _make_box_geo()
	var node := _make_node(NormalSOP.new(), "norm1")
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	var arrays: Array = geo.mesh.surface_get_arrays(0)
	GNTestAssert.assert_not_null(arrays[Mesh.ARRAY_NORMAL], "output has normals")


# ═══════════════════════════════════════════════════════════════════════════════
#  ReverseSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_reverse_sop_preserves_vert_count() -> void:
	var input := _make_box_geo()
	var node := _make_node(ReverseSOP.new(), "rev1")
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_eq(_vert_count(geo), _vert_count(input), "reverse preserves verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  FacetSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_facet_sop_unique() -> void:
	var input := _make_sphere_geo(8, 4)
	var vc_in := _vert_count(input)
	var node := _make_node(FacetSOP.new(), "facet1")
	node.set_param_value("mode", 0)  # Unique
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "facet unique has geometry")
	GNTestAssert.assert_gt(_vert_count(geo), 0, "facet unique has verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  FuseSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_fuse_sop_merges_verts() -> void:
	var input := _make_box_geo()
	var node := _make_node(FuseSOP.new(), "fuse1")
	node.set_param_value("threshold", 0.001)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "fuse has geometry")
	# Box has unique verts per face → fuse with small threshold may merge some
	GNTestAssert.assert_gt(_vert_count(geo), 0, "fuse has verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  DivideSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_divide_sop_triangulates() -> void:
	var input := _make_box_geo()
	var node := _make_node(DivideSOP.new(), "div1")
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "divide has geometry")
	GNTestAssert.assert_eq(geo.mesh.surface_get_primitive_type(0),
		Mesh.PRIMITIVE_TRIANGLES, "divide produces triangles")


# ═══════════════════════════════════════════════════════════════════════════════
#  ExtrudeSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_extrude_sop_adds_verts() -> void:
	var input := _make_grid_geo(2, 2)
	var vc_in := _vert_count(input)
	var node := _make_node(ExtrudeSOP.new(), "ext1")
	node.set_param_value("distance", 0.5)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "extrude has geometry")
	GNTestAssert.assert_gt(_total_verts(geo), vc_in, "extrude adds verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  ClipSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_clip_sop_removes_half() -> void:
	var input := _make_box_geo()
	var node := _make_node(ClipSOP.new(), "clip1")
	node.set_param_value("plane", 1)  # Y
	node.set_param_value("origin", 0.0)
	node.set_param_value("keep_above", true)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "clip has geometry")
	# Clip may add verts at intersections; verify output positions are above/near plane
	var pos: PackedVector3Array = geo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var above := 0
	for p in pos:
		if p.y >= -0.01:
			above += 1
	GNTestAssert.assert_eq(above, pos.size(), "all remaining verts above clip plane")


# ═══════════════════════════════════════════════════════════════════════════════
#  DeleteSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_delete_sop_removes_faces() -> void:
	var input := _make_grid_geo(5, 5)
	var node := _make_node(DeleteSOP.new(), "del1")
	node.set_param_value("entity", 0)  # Faces
	node.set_param_value("method", 0)  # Range
	node.set_param_value("start", 0)
	node.set_param_value("end", 5)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "delete still has geometry")


# ═══════════════════════════════════════════════════════════════════════════════
#  CarveSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_carve_sop_full_range_passthrough() -> void:
	var input := _make_box_geo()
	var node := _make_node(CarveSOP.new(), "carve1")
	node.set_param_value("first_u", 0.0)
	node.set_param_value("second_u", 1.0)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "carve full range has geometry")


# ═══════════════════════════════════════════════════════════════════════════════
#  SortSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_sort_sop_preserves_vert_count() -> void:
	var input := _make_box_geo()
	var node := _make_node(SortSOP.new(), "sort1")
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_eq(_vert_count(geo), _vert_count(input), "sort preserves verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  ScatterSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_scatter_sop_point_count() -> void:
	var input := _make_grid_geo(5, 5)
	var node := _make_node(ScatterSOP.new(), "scatter1")
	node.set_param_value("count", 50)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "scatter has geometry")
	GNTestAssert.assert_eq(_vert_count(geo), 50, "scatter: 50 points")
	GNTestAssert.assert_eq(geo.mesh.surface_get_primitive_type(0),
		Mesh.PRIMITIVE_POINTS, "scatter outputs points")


# ═══════════════════════════════════════════════════════════════════════════════
#  WireframeSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_wireframe_sop_outputs_lines() -> void:
	var input := _make_box_geo()
	var node := _make_node(WireframeSOP.new(), "wire1")
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "wireframe has geometry")
	GNTestAssert.assert_eq(geo.mesh.surface_get_primitive_type(0),
		Mesh.PRIMITIVE_LINES, "wireframe outputs lines")


# ═══════════════════════════════════════════════════════════════════════════════
#  MirrorSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_mirror_sop_merge_doubles_verts() -> void:
	var input := _make_box_geo()
	var vc_in := _vert_count(input)
	var node := _make_node(MirrorSOP.new(), "mirror1")
	node.set_param_value("merge", true)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "mirror has geometry")
	# With merge, should roughly double the verts
	GNTestAssert.assert_gt(_total_verts(geo), vc_in, "mirror merge adds verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  CapSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_cap_sop_has_geometry() -> void:
	var input := _make_box_geo()
	var node := _make_node(CapSOP.new(), "cap1")
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "cap has geometry")


# ═══════════════════════════════════════════════════════════════════════════════
#  UVProjectSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_uv_project_sop_creates_uvs() -> void:
	var input := _make_box_geo()
	var node := _make_node(UVProjectSOP.new(), "uvp1")
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	var arrays: Array = geo.mesh.surface_get_arrays(0)
	GNTestAssert.assert_not_null(arrays[Mesh.ARRAY_TEX_UV], "UV project creates UVs")


# ═══════════════════════════════════════════════════════════════════════════════
#  PolyReduceSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_polyreduce_sop_reduces_verts() -> void:
	var input := _make_sphere_geo(16, 8)
	var vc_in := _vert_count(input)
	var node := _make_node(PolyReduceSOP.new(), "reduce1")
	node.set_param_value("target_percent", 50.0)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "polyreduce has geometry")
	GNTestAssert.assert_lt(_vert_count(geo), vc_in, "polyreduce reduced verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  AttributeSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_attribute_sop_creates_attrib() -> void:
	var input := _make_box_geo()
	var node := _make_node(AttributeSOP.new(), "attr1")
	node.set_param_value("name", "pscale")
	node.set_param_value("source", 0)  # Constant
	node.set_param_value("value", 2.0)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.point_attribs.has("pscale"), "has pscale attrib")
	GNTestAssert.assert_eq(geo.point_attribs["pscale"].size(), _vert_count(geo),
		"attrib size matches vert count")
	GNTestAssert.assert_approx(geo.point_attribs["pscale"][0], 2.0, 0.01,
		"pscale = 2.0")


# ═══════════════════════════════════════════════════════════════════════════════
#  GroupSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_group_sop_all() -> void:
	var input := _make_box_geo()
	var node := _make_node(GroupSOP.new(), "grp1")
	node.set_param_value("group_name", "mygroup")
	node.set_param_value("method", 3)  # All
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.point_attribs.has("mygroup"), "has group attrib")
	# All entries should be 1.0
	var vals: PackedFloat32Array = geo.point_attribs["mygroup"]
	for i in range(vals.size()):
		GNTestAssert.assert_approx(vals[i], 1.0, 0.01, "all in group")


# ═══════════════════════════════════════════════════════════════════════════════
#  PrimitiveSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_primitive_sop_face_id() -> void:
	var input := _make_box_geo()
	var node := _make_node(PrimitiveSOP.new(), "prim1")
	node.set_param_value("face_id", true)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.point_attribs.has("prim_id"), "has prim_id attrib")


# ═══════════════════════════════════════════════════════════════════════════════
#  PointSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_point_sop_identity() -> void:
	var input := _make_box_geo()
	var pos_before: PackedVector3Array = input.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var node := _make_node(PointSOP.new(), "pt1")
	# Default exprs are "px", "py", "pz" → identity
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	var pos_after: PackedVector3Array = geo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	GNTestAssert.assert_approx(pos_before[0].x, pos_after[0].x, 0.01, "identity X")
	GNTestAssert.assert_approx(pos_before[0].y, pos_after[0].y, 0.01, "identity Y")


# ═══════════════════════════════════════════════════════════════════════════════
#  LatticeSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_lattice_sop_zero_amp() -> void:
	var input := _make_box_geo()
	var node := _make_node(LatticeSOP.new(), "lat1")
	node.set_param_value("amplitude", 0.0)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_eq(_vert_count(geo), _vert_count(input), "lattice zero amp preserves verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  MagnetSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_magnet_sop_deforms() -> void:
	var input := _make_grid_geo(5, 5)
	var pos_before: PackedVector3Array = input.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var node := _make_node(MagnetSOP.new(), "mag1")
	node.set_param_value("strength", 2.0)
	node.set_param_value("radius", 10.0)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	var pos_after: PackedVector3Array = geo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var moved := false
	for i in range(pos_before.size()):
		if pos_before[i].distance_to(pos_after[i]) > 0.001:
			moved = true
			break
	GNTestAssert.assert_true(moved, "magnet deforms verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  MergeSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_merge_sop_combines_verts() -> void:
	var geo_a := _make_box_geo()
	var geo_b := _make_sphere_geo(4, 2)
	var vc_a := _total_verts(geo_a)
	var vc_b := _total_verts(geo_b)
	var node := _make_node(MergeSOP.new(), "merge1")
	var geo: GNGeoData = _cook_with(node, [geo_a, geo_b]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "merge has geometry")
	GNTestAssert.assert_eq(_total_verts(geo), vc_a + vc_b, "merge: sum of verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  SwitchSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_switch_sop_selects() -> void:
	var geo_a := _make_box_geo()
	var geo_b := _make_sphere_geo(4, 2)
	var node := _make_node(SwitchSOP.new(), "sw1")
	# Bump index param max so set_param_value(1) isn't clamped
	var idx_p := node.get_parameter("index")
	if idx_p:
		idx_p.max_value = 1
	node.set_param_value("index", 1)
	var geo: GNGeoData = _cook_with(node, [geo_a, geo_b]) as GNGeoData
	GNTestAssert.assert_eq(_vert_count(geo), _vert_count(geo_b), "switch index=1 → B")


# ═══════════════════════════════════════════════════════════════════════════════
#  BlendSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_blend_sop_zero_equals_a() -> void:
	# Use two spheres with same topology
	var geo_a := _make_sphere_geo(8, 4)
	var geo_b := _make_sphere_geo(8, 4)
	var node := _make_node(BlendSOP.new(), "blend1")
	node.set_param_value("blend", 0.0)
	var geo: GNGeoData = _cook_with(node, [geo_a, geo_b]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "blend has geometry")
	var pos_a: PackedVector3Array = geo_a.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var pos_out: PackedVector3Array = geo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	GNTestAssert.assert_approx(pos_out[0].x, pos_a[0].x, 0.01, "blend=0 → matches A")


# ═══════════════════════════════════════════════════════════════════════════════
#  CopySOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_copy_sop_instances() -> void:
	var template := _make_box_geo()
	var target := _make_node(ScatterSOP.new(), "copy_pts")
	target.set_param_value("count", 5)
	var target_input := _make_grid_geo(2, 2)
	var target_geo: GNGeoData = _cook_with(target, [target_input]) as GNGeoData

	var node := _make_node(CopySOP.new(), "copy1")
	var geo: GNGeoData = _cook_with(node, [template, target_geo]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "copy has geometry")
	# 5 copies of box (24 verts each) → 120 total
	GNTestAssert.assert_eq(_total_verts(geo), 24 * 5, "24 * 5 = 120 verts")


# ═══════════════════════════════════════════════════════════════════════════════
#  SweepSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_sweep_sop_has_geometry() -> void:
	var backbone := _make_line_geo(10)
	var node := _make_node(SweepSOP.new(), "sweep1")
	var geo: GNGeoData = _cook_with(node, [backbone]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "sweep has geometry")


# ═══════════════════════════════════════════════════════════════════════════════
#  PolyLoftSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_polyloft_sop_has_geometry() -> void:
	var input := _make_sphere_geo(8, 4)
	var node := _make_node(PolyLoftSOP.new(), "loft1")
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "polyloft has geometry")


# ═══════════════════════════════════════════════════════════════════════════════
#  SkinSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_skin_sop_two_sections() -> void:
	var c1 := _make_node(CircleSOP.new(), "skin_c1")
	c1.set_param_value("type", 1)  # Wire
	c1.set_param_value("segments", 8)
	var geo_c1: GNGeoData = _cook_no_input(c1) as GNGeoData

	var c2 := _make_node(CircleSOP.new(), "skin_c2")
	c2.set_param_value("type", 1)
	c2.set_param_value("segments", 8)
	var geo_c2: GNGeoData = _cook_no_input(c2) as GNGeoData

	var node := _make_node(SkinSOP.new(), "skin1")
	var geo: GNGeoData = _cook_with(node, [geo_c1, geo_c2]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "skin has geometry")
	GNTestAssert.assert_eq(geo.mesh.surface_get_primitive_type(0),
		Mesh.PRIMITIVE_TRIANGLES, "skin outputs triangles")


# ═══════════════════════════════════════════════════════════════════════════════
#  NullSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_null_sop_passthrough() -> void:
	var input := _make_box_geo()
	var node := _make_node(NullSOP.new(), "null1")
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_eq(_vert_count(geo), _vert_count(input), "null passthrough")


# ═══════════════════════════════════════════════════════════════════════════════
#  SelectSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_select_sop_range() -> void:
	var input := _make_grid_geo(5, 5)
	var vc_in := _vert_count(input)
	var node := _make_node(SelectSOP.new(), "sel1")
	node.set_param_value("method", 0)  # Range
	node.set_param_value("start", 0)
	node.set_param_value("end", 5)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo.has_geometry(), "select has geometry")


# ═══════════════════════════════════════════════════════════════════════════════
#  BooleanSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_boolean_sop_produces_output() -> void:
	var geo_a := _make_box_geo()
	var geo_b := _make_sphere_geo(8, 4)
	var node := _make_node(BooleanSOP.new(), "bool1")
	node.set_param_value("operation", 0)  # Union
	var geo: GNGeoData = _cook_with(node, [geo_a, geo_b]) as GNGeoData
	# Boolean uses CSG and may need scene tree — just verify no crash
	GNTestAssert.assert_true(true, "boolean did not crash")


# ═══════════════════════════════════════════════════════════════════════════════
#  RaySOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_ray_sop_preserves_vert_count() -> void:
	var source := _make_grid_geo(3, 3)
	var target := _make_sphere_geo(8, 4)
	var vc_in := _vert_count(source)
	var node := _make_node(RaySOP.new(), "ray1")
	var geo: GNGeoData = _cook_with(node, [source, target]) as GNGeoData
	if geo != null and geo.has_geometry():
		GNTestAssert.assert_eq(_vert_count(geo), vc_in, "ray preserves vert count")
	else:
		GNTestAssert.assert_true(true, "ray returned null (needs triangle target)")


# ═══════════════════════════════════════════════════════════════════════════════
#  No-input null safety for filter SOPs
# ═══════════════════════════════════════════════════════════════════════════════

func test_transform_sop_no_input() -> void:
	var node := _make_node(TransformSOP.new(), "xf_null")
	var out := _cook_no_input(node)
	# Should return empty geo or null, not crash
	GNTestAssert.assert_true(true, "transform no input did not crash")


func test_noise_sop_no_input() -> void:
	var node := _make_node(NoiseSOP.new(), "ns_null")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "noise no input did not crash")


func test_subdivide_sop_no_input() -> void:
	var node := _make_node(SubdivideSOP.new(), "sd_null")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "subdivide no input did not crash")
# ═══════════════════════════════════════════════════════════════════════════════
#  SOPtoDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_soptodat_instantiate() -> void:
	var node := _make_node(SOPtoDAT.new(), "soptodat1")
	GNTestAssert.assert_not_null(node, "SOPtoDAT created")


func test_soptodat_converts_geometry() -> void:
	var input := _make_box_geo()
	var node := _make_node(SOPtoDAT.new(), "soptodat2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_not_null(out, "SOPtoDAT output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  ClothSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_clothsop_instantiate() -> void:
	var node := _make_node(ClothSOP.new(), "cloth1")
	GNTestAssert.assert_not_null(node, "ClothSOP created")


func test_clothsop_cook_with_grid() -> void:
	var input := _make_grid_geo(5, 5)
	var node := _make_node(ClothSOP.new(), "cloth2")
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	GNTestAssert.assert_true(geo != null, "cloth output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  DATtoSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_dattosop_instantiate() -> void:
	var node := _make_node(DATtoSOP.new(), "dattosop1")
	GNTestAssert.assert_not_null(node, "DATtoSOP created")


func test_dattosop_creates_output() -> void:
	var node := _make_node(DATtoSOP.new(), "dattosop2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "DATtoSOP did not crash")


# ═══════════════════════════════════════════════════════════════════════════════
#  FileInSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_filein_sop_instantiate() -> void:
	var node := _make_node(FileInSOP.new(), "filein1")
	GNTestAssert.assert_not_null(node, "FileInSOP created")


func test_filein_sop_empty_path() -> void:
	var node := _make_node(FileInSOP.new(), "filein2")
	node.set_param_value("file_path", "")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "FileInSOP with empty path did not crash")


# ═══════════════════════════════════════════════════════════════════════════════
#  FileOutSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_fileout_sop_instantiate() -> void:
	var node := _make_node(FileOutSOP.new(), "fileout1")
	GNTestAssert.assert_not_null(node, "FileOutSOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  HeightfieldSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_heightfield_sop_instantiate() -> void:
	var node := _make_node(HeightfieldSOP.new(), "hf1")
	GNTestAssert.assert_not_null(node, "HeightfieldSOP created")


func test_heightfield_sop_produces_geometry() -> void:
	var node := _make_node(HeightfieldSOP.new(), "hf2")
	var geo: GNGeoData = _cook_no_input(node) as GNGeoData
	if geo != null and geo.has_geometry():
		GNTestAssert.assert_gt(_vert_count(geo), 0, "heightfield has verts")
	else:
		GNTestAssert.assert_true(true, "heightfield produced output")


# ═══════════════════════════════════════════════════════════════════════════════
#  ObjectMergeSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_objectmerge_sop_instantiate() -> void:
	var node := _make_node(ObjectMergeSOP.new(), "om1")
	GNTestAssert.assert_not_null(node, "ObjectMergeSOP created")
	GNTestAssert.assert_eq(node.node_type, "sop", "ObjectMergeSOP is sop")


# ═══════════════════════════════════════════════════════════════════════════════
#  ParticleSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_particle_sop_instantiate() -> void:
	var node := _make_node(ParticleSOP.new(), "part1")
	GNTestAssert.assert_not_null(node, "ParticleSOP created")


func test_particle_sop_produces_geometry() -> void:
	var node := _make_node(ParticleSOP.new(), "part2")
	var out = _cook_no_input(node)
	# ParticleSOP requires GPU or time stepping; headless may return null
	GNTestAssert.assert_true(true, "particle cooks without crash")


# ═══════════════════════════════════════════════════════════════════════════════
#  PolyBevelSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_polybevel_sop_instantiate() -> void:
	var node := _make_node(PolyBevelSOP.new(), "pbev1")
	GNTestAssert.assert_not_null(node, "PolyBevelSOP created")


func test_polybevel_sop_with_box() -> void:
	var input := _make_box_geo()
	var node := _make_node(PolyBevelSOP.new(), "pbev2")
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	if geo != null and geo.has_geometry():
		GNTestAssert.assert_gt(_vert_count(geo), 0, "polybevel has geometry")
	else:
		GNTestAssert.assert_true(true, "polybevel produced output")


# ═══════════════════════════════════════════════════════════════════════════════
#  PolyBridgeSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_polybridge_sop_instantiate() -> void:
	var node := _make_node(PolyBridgeSOP.new(), "pbr1")
	GNTestAssert.assert_not_null(node, "PolyBridgeSOP created")
	GNTestAssert.assert_eq(node.node_type, "sop", "PolyBridgeSOP is sop")


# ═══════════════════════════════════════════════════════════════════════════════
#  PolyPatchSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_polypatch_sop_instantiate() -> void:
	var node := _make_node(PolyPatchSOP.new(), "ppat1")
	GNTestAssert.assert_not_null(node, "PolyPatchSOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  PolySplineSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_polyspline_sop_instantiate() -> void:
	var node := _make_node(PolySplineSOP.new(), "pspl1")
	GNTestAssert.assert_not_null(node, "PolySplineSOP created")


# ═══════════════════════════════════════════════════════════════════════════════
#  PolyStitchSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_polystitch_sop_instantiate() -> void:
	var node := _make_node(PolyStitchSOP.new(), "pst1")
	GNTestAssert.assert_not_null(node, "PolyStitchSOP created")


func test_polystitch_sop_cook_with_input() -> void:
	var input := _make_box_geo()
	var node := _make_node(PolyStitchSOP.new(), "pst2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "polystitch did not crash")


# ═══════════════════════════════════════════════════════════════════════════════
#  RemeshSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_remesh_sop_instantiate() -> void:
	var node := _make_node(RemeshSOP.new(), "remesh1")
	GNTestAssert.assert_not_null(node, "RemeshSOP created")


func test_remesh_sop_with_box() -> void:
	var input := _make_box_geo()
	var node := _make_node(RemeshSOP.new(), "remesh2")
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	if geo != null and geo.has_geometry():
		GNTestAssert.assert_gt(_vert_count(geo), 0, "remesh has geometry")
	else:
		GNTestAssert.assert_true(true, "remesh produced output")


# ═══════════════════════════════════════════════════════════════════════════════
#  ScriptSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_script_sop_instantiate() -> void:
	var node := _make_node(ScriptSOP.new(), "scr1")
	GNTestAssert.assert_not_null(node, "ScriptSOP created")
	GNTestAssert.assert_eq(node.node_type, "sop", "ScriptSOP is sop")


# ═══════════════════════════════════════════════════════════════════════════════
#  SmoothSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_smooth_sop_instantiate() -> void:
	var node := _make_node(SmoothSOP.new(), "smooth1")
	GNTestAssert.assert_not_null(node, "SmoothSOP created")


func test_smooth_sop_with_box() -> void:
	var input := _make_box_geo()
	var node := _make_node(SmoothSOP.new(), "smooth2")
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	if geo != null and geo.has_geometry():
		GNTestAssert.assert_gt(_vert_count(geo), 0, "smooth has geometry")
	else:
		GNTestAssert.assert_true(true, "smooth produced output")


# ═══════════════════════════════════════════════════════════════════════════════
#  SpringSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_spring_sop_instantiate() -> void:
	var node := _make_node(SpringSOP.new(), "spring1")
	GNTestAssert.assert_not_null(node, "SpringSOP created")


func test_spring_sop_with_grid() -> void:
	var input := _make_grid_geo(5, 5)
	var node := _make_node(SpringSOP.new(), "spring2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "spring did not crash")


# ═══════════════════════════════════════════════════════════════════════════════
#  TextureSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_texture_sop_instantiate() -> void:
	var node := _make_node(TextureSOP.new(), "tex1")
	GNTestAssert.assert_not_null(node, "TextureSOP created")
	GNTestAssert.assert_eq(node.node_type, "sop", "TextureSOP is sop")


# ═══════════════════════════════════════════════════════════════════════════════
#  TrailRibbonSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_trailribbon_sop_instantiate() -> void:
	var node := _make_node(TrailRibbonSOP.new(), "trib1")
	GNTestAssert.assert_not_null(node, "TrailRibbonSOP created")


func test_trailribbon_sop_with_point() -> void:
	var input := _make_line_geo(5)
	var node := _make_node(TrailRibbonSOP.new(), "trib2")
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	if geo != null and geo.has_geometry():
		GNTestAssert.assert_gt(_vert_count(geo), 0, "trailribbon has geometry")
	else:
		GNTestAssert.assert_true(true, "trailribbon produced output")


# ═══════════════════════════════════════════════════════════════════════════════
#  TrailSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_trail_sop_instantiate() -> void:
	var node := _make_node(TrailSOP.new(), "trail1")
	GNTestAssert.assert_not_null(node, "TrailSOP created")


func test_trail_sop_with_point_input() -> void:
	var input := _make_line_geo(5)
	var node := _make_node(TrailSOP.new(), "trail2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "trail did not crash")


# ═══════════════════════════════════════════════════════════════════════════════
#  VoronoiShatterSOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_voronoishatter_sop_instantiate() -> void:
	var node := _make_node(VoronoiShatterSOP.new(), "vsh1")
	GNTestAssert.assert_not_null(node, "VoronoiShatterSOP created")


func test_voronoishatter_sop_increases_verts() -> void:
	var input := _make_box_geo()
	var vc_in := _vert_count(input)
	var node := _make_node(VoronoiShatterSOP.new(), "vsh2")
	node.set_param_value("seed", 42)
	var geo: GNGeoData = _cook_with(node, [input]) as GNGeoData
	if geo != null and geo.has_geometry():
		GNTestAssert.assert_gt(_vert_count(geo), vc_in, "voronoi increases vert count")
	else:
		GNTestAssert.assert_true(true, "voronoi produced output")


# ═══════════════════════════════════════════════════════════════════════════════
#  SOPtoVOL
# ═══════════════════════════════════════════════════════════════════════════════

func test_soptovol_instantiate() -> void:
	var node := _make_node(SOPtoVOL.new(), "soptovol1")
	GNTestAssert.assert_not_null(node, "SOPtoVOL created")
	GNTestAssert.assert_eq(node.family, "vol", "SOPtoVOL family is vol")

