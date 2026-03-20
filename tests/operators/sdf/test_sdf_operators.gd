extends Node
## Correctness tests for SDF operators.
##
## SDF operators produce GNSDFData containing an AST tree structure.
## Primitives (box, sphere, etc.) create leaf nodes; modifiers (bend, twist)
## wrap children. All belong to the TOP family.

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


## Helper: creates a BoxSDF, cooks it, returns GNSDFData for use as input.
func _make_box_sdf() -> GNSDFData:
	var box := _make_node(BoxSDF.new(), "box_%d" % randi())
	var out := _cook_no_input(box)
	if out is GNSDFData:
		return out
	return null


# ═══════════════════════════════════════════════════════════════════════════════
#  BoxSDF
# ═══════════════════════════════════════════════════════════════════════════════

func test_box_sdf_instantiate() -> void:
	var node := _make_node(BoxSDF.new(), "box1")
	GNTestAssert.assert_not_null(node, "BoxSDF created")

func test_box_sdf_produces_sdf_data() -> void:
	var node := _make_node(BoxSDF.new(), "box2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "output exists")
	GNTestAssert.assert_true(out is GNSDFData, "is GNSDFData")

func test_box_sdf_tree_has_op() -> void:
	var node := _make_node(BoxSDF.new(), "box3")
	var out: GNSDFData = _cook_no_input(node) as GNSDFData
	if out != null:
		GNTestAssert.assert_true(out.sdf_tree.has("op"), "tree has op key")
		GNTestAssert.assert_eq(out.sdf_tree["op"], "box", "op is box")


# ═══════════════════════════════════════════════════════════════════════════════
#  SphereSDF
# ═══════════════════════════════════════════════════════════════════════════════

func test_sphere_sdf_instantiate() -> void:
	var node := _make_node(SphereSDF.new(), "sphere1")
	GNTestAssert.assert_not_null(node, "SphereSDF created")

func test_sphere_sdf_produces_sdf_data() -> void:
	var node := _make_node(SphereSDF.new(), "sphere2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "output exists")
	GNTestAssert.assert_true(out is GNSDFData, "is GNSDFData")


# ═══════════════════════════════════════════════════════════════════════════════
#  CapsuleSDF
# ═══════════════════════════════════════════════════════════════════════════════

func test_capsule_sdf_instantiate() -> void:
	var node := _make_node(CapsuleSDF.new(), "capsule1")
	GNTestAssert.assert_not_null(node, "CapsuleSDF created")

func test_capsule_sdf_produces_output() -> void:
	var node := _make_node(CapsuleSDF.new(), "capsule2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "output exists")
	GNTestAssert.assert_true(out is GNSDFData, "is GNSDFData")


# ═══════════════════════════════════════════════════════════════════════════════
#  ConeSDF
# ═══════════════════════════════════════════════════════════════════════════════

func test_cone_sdf_instantiate() -> void:
	var node := _make_node(ConeSDF.new(), "cone1")
	GNTestAssert.assert_not_null(node, "ConeSDF created")

func test_cone_sdf_produces_output() -> void:
	var node := _make_node(ConeSDF.new(), "cone2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "output exists")
	GNTestAssert.assert_true(out is GNSDFData, "is GNSDFData")


# ═══════════════════════════════════════════════════════════════════════════════
#  CylinderSDF
# ═══════════════════════════════════════════════════════════════════════════════

func test_cylinder_sdf_instantiate() -> void:
	var node := _make_node(CylinderSDF.new(), "cyl1")
	GNTestAssert.assert_not_null(node, "CylinderSDF created")

func test_cylinder_sdf_produces_output() -> void:
	var node := _make_node(CylinderSDF.new(), "cyl2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  PlaneSDF
# ═══════════════════════════════════════════════════════════════════════════════

func test_plane_sdf_instantiate() -> void:
	var node := _make_node(PlaneSDF.new(), "plane1")
	GNTestAssert.assert_not_null(node, "PlaneSDF created")

func test_plane_sdf_produces_output() -> void:
	var node := _make_node(PlaneSDF.new(), "plane2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  TorusSDF
# ═══════════════════════════════════════════════════════════════════════════════

func test_torus_sdf_instantiate() -> void:
	var node := _make_node(TorusSDF.new(), "torus1")
	GNTestAssert.assert_not_null(node, "TorusSDF created")

func test_torus_sdf_produces_output() -> void:
	var node := _make_node(TorusSDF.new(), "torus2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  OctahedronSDF
# ═══════════════════════════════════════════════════════════════════════════════

func test_octahedron_sdf_instantiate() -> void:
	var node := _make_node(OctahedronSDF.new(), "oct1")
	GNTestAssert.assert_not_null(node, "OctahedronSDF created")

func test_octahedron_sdf_produces_output() -> void:
	var node := _make_node(OctahedronSDF.new(), "oct2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  PyramidSDF
# ═══════════════════════════════════════════════════════════════════════════════

func test_pyramid_sdf_instantiate() -> void:
	var node := _make_node(PyramidSDF.new(), "pyr1")
	GNTestAssert.assert_not_null(node, "PyramidSDF created")

func test_pyramid_sdf_produces_output() -> void:
	var node := _make_node(PyramidSDF.new(), "pyr2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  GyroidSDF
# ═══════════════════════════════════════════════════════════════════════════════

func test_gyroid_sdf_instantiate() -> void:
	var node := _make_node(GyroidSDF.new(), "gyroid1")
	GNTestAssert.assert_not_null(node, "GyroidSDF created")

func test_gyroid_sdf_produces_output() -> void:
	var node := _make_node(GyroidSDF.new(), "gyroid2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  GradientSDF
# ═══════════════════════════════════════════════════════════════════════════════

func test_gradient_sdf_instantiate() -> void:
	var node := _make_node(GradientSDF.new(), "grad1")
	GNTestAssert.assert_not_null(node, "GradientSDF created")

func test_gradient_sdf_produces_output() -> void:
	var node := _make_node(GradientSDF.new(), "grad2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  BendSDF — modifier (requires SDF input)
# ═══════════════════════════════════════════════════════════════════════════════

func test_bend_sdf_instantiate() -> void:
	var node := _make_node(BendSDF.new(), "bend1")
	GNTestAssert.assert_not_null(node, "BendSDF created")

func test_bend_sdf_modifies_input() -> void:
	var node := _make_node(BendSDF.new(), "bend2")
	var sdf_in := _make_box_sdf()
	if sdf_in != null:
		var out := _cook_with(node, [sdf_in])
		GNTestAssert.assert_not_null(out, "output exists")
		GNTestAssert.assert_true(out is GNSDFData, "is GNSDFData")


# ═══════════════════════════════════════════════════════════════════════════════
#  TwistSDF — modifier
# ═══════════════════════════════════════════════════════════════════════════════

func test_twist_sdf_instantiate() -> void:
	var node := _make_node(TwistSDF.new(), "twist1")
	GNTestAssert.assert_not_null(node, "TwistSDF created")

func test_twist_sdf_modifies_input() -> void:
	var node := _make_node(TwistSDF.new(), "twist2")
	var sdf_in := _make_box_sdf()
	if sdf_in != null:
		var out := _cook_with(node, [sdf_in])
		GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  DisplaceSDF — modifier
# ═══════════════════════════════════════════════════════════════════════════════

func test_displace_sdf_instantiate() -> void:
	var node := _make_node(DisplaceSDF.new(), "disp1")
	GNTestAssert.assert_not_null(node, "DisplaceSDF created")

func test_displace_sdf_modifies_input() -> void:
	var node := _make_node(DisplaceSDF.new(), "disp2")
	var sdf_in := _make_box_sdf()
	if sdf_in != null:
		var out := _cook_with(node, [sdf_in])
		GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  ElongateSDF — modifier
# ═══════════════════════════════════════════════════════════════════════════════

func test_elongate_sdf_instantiate() -> void:
	var node := _make_node(ElongateSDF.new(), "elong1")
	GNTestAssert.assert_not_null(node, "ElongateSDF created")

func test_elongate_sdf_modifies_input() -> void:
	var node := _make_node(ElongateSDF.new(), "elong2")
	var sdf_in := _make_box_sdf()
	if sdf_in != null:
		var out := _cook_with(node, [sdf_in])
		GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  MirrorSDF — modifier
# ═══════════════════════════════════════════════════════════════════════════════

func test_mirror_sdf_instantiate() -> void:
	var node := _make_node(MirrorSDF.new(), "mirror1")
	GNTestAssert.assert_not_null(node, "MirrorSDF created")

func test_mirror_sdf_modifies_input() -> void:
	var node := _make_node(MirrorSDF.new(), "mirror2")
	var sdf_in := _make_box_sdf()
	if sdf_in != null:
		var out := _cook_with(node, [sdf_in])
		GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  OnionSDF — modifier
# ═══════════════════════════════════════════════════════════════════════════════

func test_onion_sdf_instantiate() -> void:
	var node := _make_node(OnionSDF.new(), "onion1")
	GNTestAssert.assert_not_null(node, "OnionSDF created")

func test_onion_sdf_modifies_input() -> void:
	var node := _make_node(OnionSDF.new(), "onion2")
	var sdf_in := _make_box_sdf()
	if sdf_in != null:
		var out := _cook_with(node, [sdf_in])
		GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  RepeatSDF — modifier
# ═══════════════════════════════════════════════════════════════════════════════

func test_repeat_sdf_instantiate() -> void:
	var node := _make_node(RepeatSDF.new(), "repeat1")
	GNTestAssert.assert_not_null(node, "RepeatSDF created")

func test_repeat_sdf_modifies_input() -> void:
	var node := _make_node(RepeatSDF.new(), "repeat2")
	var sdf_in := _make_box_sdf()
	if sdf_in != null:
		var out := _cook_with(node, [sdf_in])
		GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  RoundSDF — modifier
# ═══════════════════════════════════════════════════════════════════════════════

func test_round_sdf_instantiate() -> void:
	var node := _make_node(RoundSDF.new(), "round1")
	GNTestAssert.assert_not_null(node, "RoundSDF created")

func test_round_sdf_modifies_input() -> void:
	var node := _make_node(RoundSDF.new(), "round2")
	var sdf_in := _make_box_sdf()
	if sdf_in != null:
		var out := _cook_with(node, [sdf_in])
		GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  UnionSDF — combiner (2 inputs)
# ═══════════════════════════════════════════════════════════════════════════════

func test_union_sdf_instantiate() -> void:
	var node := _make_node(UnionSDF.new(), "union1")
	GNTestAssert.assert_not_null(node, "UnionSDF created")

func test_union_sdf_combines_inputs() -> void:
	var node := _make_node(UnionSDF.new(), "union2")
	var a := _make_box_sdf()
	var b_node := _make_node(SphereSDF.new(), "union_sphere")
	var b := _cook_no_input(b_node) as GNSDFData
	if a != null and b != null:
		var out := _cook_with(node, [a, b])
		GNTestAssert.assert_not_null(out, "output exists")
		GNTestAssert.assert_true(out is GNSDFData, "is GNSDFData")


# ═══════════════════════════════════════════════════════════════════════════════
#  SubtractSDF — combiner
# ═══════════════════════════════════════════════════════════════════════════════

func test_subtract_sdf_instantiate() -> void:
	var node := _make_node(SubtractSDF.new(), "sub1")
	GNTestAssert.assert_not_null(node, "SubtractSDF created")

func test_subtract_sdf_combines_inputs() -> void:
	var node := _make_node(SubtractSDF.new(), "sub2")
	var a := _make_box_sdf()
	var b_node := _make_node(SphereSDF.new(), "sub_sphere")
	var b := _cook_no_input(b_node) as GNSDFData
	if a != null and b != null:
		var out := _cook_with(node, [a, b])
		GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  IntersectionSDF — combiner
# ═══════════════════════════════════════════════════════════════════════════════

func test_intersection_sdf_instantiate() -> void:
	var node := _make_node(IntersectionSDF.new(), "inter1")
	GNTestAssert.assert_not_null(node, "IntersectionSDF created")

func test_intersection_sdf_combines_inputs() -> void:
	var node := _make_node(IntersectionSDF.new(), "inter2")
	var a := _make_box_sdf()
	var b_node := _make_node(SphereSDF.new(), "inter_sphere")
	var b := _cook_no_input(b_node) as GNSDFData
	if a != null and b != null:
		var out := _cook_with(node, [a, b])
		GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  SmoothUnionSDF — smooth combiner
# ═══════════════════════════════════════════════════════════════════════════════

func test_smooth_union_sdf_instantiate() -> void:
	var node := _make_node(SmoothUnionSDF.new(), "smunion1")
	GNTestAssert.assert_not_null(node, "SmoothUnionSDF created")

func test_smooth_union_sdf_combines_inputs() -> void:
	var node := _make_node(SmoothUnionSDF.new(), "smunion2")
	node.set_param_value("smoothness", 0.2)
	var a := _make_box_sdf()
	var b_node := _make_node(SphereSDF.new(), "smunion_sphere")
	var b := _cook_no_input(b_node) as GNSDFData
	if a != null and b != null:
		var out := _cook_with(node, [a, b])
		GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  SmoothSubtractSDF — smooth combiner
# ═══════════════════════════════════════════════════════════════════════════════

func test_smooth_subtract_sdf_instantiate() -> void:
	var node := _make_node(SmoothSubtractSDF.new(), "smsub1")
	GNTestAssert.assert_not_null(node, "SmoothSubtractSDF created")

func test_smooth_subtract_sdf_combines_inputs() -> void:
	var node := _make_node(SmoothSubtractSDF.new(), "smsub2")
	node.set_param_value("smoothness", 0.1)
	var a := _make_box_sdf()
	var b_node := _make_node(SphereSDF.new(), "smsub_sphere")
	var b := _cook_no_input(b_node) as GNSDFData
	if a != null and b != null:
		var out := _cook_with(node, [a, b])
		GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  MaterialSDF — applies material
# ═══════════════════════════════════════════════════════════════════════════════

func test_material_sdf_instantiate() -> void:
	var node := _make_node(MaterialSDF.new(), "matsdf1")
	GNTestAssert.assert_not_null(node, "MaterialSDF created")

func test_material_sdf_applies_to_input() -> void:
	var node := _make_node(MaterialSDF.new(), "matsdf2")
	var sdf_in := _make_box_sdf()
	if sdf_in != null:
		var out := _cook_with(node, [sdf_in])
		GNTestAssert.assert_not_null(out, "output exists")


# ═══════════════════════════════════════════════════════════════════════════════
#  RaymarchSDF — renders SDF scene to texture
# ═══════════════════════════════════════════════════════════════════════════════

func test_raymarch_sdf_instantiate() -> void:
	var node := _make_node(RaymarchSDF.new(), "ray1")
	GNTestAssert.assert_not_null(node, "RaymarchSDF created")

func test_raymarch_sdf_render() -> void:
	var node := _make_node(RaymarchSDF.new(), "ray2")
	var sdf_in := _make_box_sdf()
	if sdf_in != null:
		var out := _cook_with(node, [sdf_in])
		# RaymarchSDF produces GNTextureData, not GNSDFData
		GNTestAssert.assert_not_null(out, "output exists")
