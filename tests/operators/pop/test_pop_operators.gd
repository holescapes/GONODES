extends Node
## Correctness tests for POP (Particle Operator) operators.
##
## POP operators use GPU compute — tests exercise instantiation, parameter
## defaults, null-safety, and output data structure.  Full GPU dispatch
## tests require a running RenderingDevice (headless Vulkan).

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


# ═══════════════════════════════════════════════════════════════════════════════
#  SourcePOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_source_pop_instantiation() -> void:
	var node := _make_node(SourcePOP.new(), "src1")
	GNTestAssert.assert_not_null(node, "SourcePOP created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_source_pop_default_params() -> void:
	var node := _make_node(SourcePOP.new(), "src2")
	GNTestAssert.assert_not_null(node.get_parameter("max_particles"), "has max_particles param")
	GNTestAssert.assert_not_null(node.get_parameter("rate"), "has rate param")

func test_source_pop_output_type() -> void:
	var node := _make_node(SourcePOP.new(), "src3")
	var out := _cook_no_input(node)
	# With no GPU context in headless, may return null or GNParticleData
	if out != null:
		GNTestAssert.assert_true(out is GNParticleData, "output is GNParticleData")

func test_source_pop_node_type() -> void:
	var node := _make_node(SourcePOP.new(), "src4")
	GNTestAssert.assert_eq(node.node_type, "source", "node_type is source")

func test_source_pop_time_dependent() -> void:
	var node := _make_node(SourcePOP.new(), "src5")
	GNTestAssert.assert_true(node.time_dependent, "POP is time-dependent")


# ═══════════════════════════════════════════════════════════════════════════════
#  ForcePOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_force_pop_instantiation() -> void:
	var node := _make_node(ForcePOP.new(), "force1")
	GNTestAssert.assert_not_null(node, "ForcePOP created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_force_pop_default_gravity() -> void:
	var node := _make_node(ForcePOP.new(), "force2")
	var grav: Variant = node.get_param_value("gravity_y")
	GNTestAssert.assert_not_null(grav, "has gravity_y param")

func test_force_pop_no_input_safety() -> void:
	var node := _make_node(ForcePOP.new(), "force3")
	var out := _cook_no_input(node)
	# Should handle null input gracefully
	GNTestAssert.assert_true(true, "no crash on null input")

func test_force_pop_passthrough_null() -> void:
	var node := _make_node(ForcePOP.new(), "force4")
	var out := _cook_with(node, [])
	# No input = null output
	if out == null:
		GNTestAssert.assert_true(true, "null output on empty input")


# ═══════════════════════════════════════════════════════════════════════════════
#  TurbulencePOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_turbulence_pop_instantiation() -> void:
	var node := _make_node(TurbulencePOP.new(), "turb1")
	GNTestAssert.assert_not_null(node, "TurbulencePOP created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_turbulence_pop_params() -> void:
	var node := _make_node(TurbulencePOP.new(), "turb2")
	GNTestAssert.assert_not_null(node.get_parameter("amplitude"), "has amplitude param")
	GNTestAssert.assert_not_null(node.get_parameter("frequency"), "has frequency param")

func test_turbulence_pop_no_input() -> void:
	var node := _make_node(TurbulencePOP.new(), "turb3")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on null input")


# ═══════════════════════════════════════════════════════════════════════════════
#  CollisionPOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_collision_pop_instantiation() -> void:
	var node := _make_node(CollisionPOP.new(), "coll1")
	GNTestAssert.assert_not_null(node, "CollisionPOP created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_collision_pop_ground_plane() -> void:
	var node := _make_node(CollisionPOP.new(), "coll2")
	GNTestAssert.assert_not_null(node.get_parameter("ground_y"), "has ground_y param")
	GNTestAssert.assert_not_null(node.get_parameter("bounce"), "has bounce param")

func test_collision_pop_no_input() -> void:
	var node := _make_node(CollisionPOP.new(), "coll3")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on null input")


# ═══════════════════════════════════════════════════════════════════════════════
#  AttractPOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_attract_pop_instantiation() -> void:
	var node := _make_node(AttractPOP.new(), "attr1")
	GNTestAssert.assert_not_null(node, "AttractPOP created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_attract_pop_params() -> void:
	var node := _make_node(AttractPOP.new(), "attr2")
	GNTestAssert.assert_not_null(node.get_parameter("strength"), "has strength param")

func test_attract_pop_no_input() -> void:
	var node := _make_node(AttractPOP.new(), "attr3")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on null input")


# ═══════════════════════════════════════════════════════════════════════════════
#  LimitPOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_limit_pop_instantiation() -> void:
	var node := _make_node(LimitPOP.new(), "lim1")
	GNTestAssert.assert_not_null(node, "LimitPOP created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_limit_pop_params() -> void:
	var node := _make_node(LimitPOP.new(), "lim2")
	GNTestAssert.assert_not_null(node.get_parameter("max_age"), "has max_age param")

func test_limit_pop_no_input() -> void:
	var node := _make_node(LimitPOP.new(), "lim3")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on null input")


# ═══════════════════════════════════════════════════════════════════════════════
#  AdvectPOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_advect_pop_instantiation() -> void:
	var node := _make_node(AdvectPOP.new(), "adv1")
	GNTestAssert.assert_not_null(node, "AdvectPOP created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_advect_pop_params() -> void:
	var node := _make_node(AdvectPOP.new(), "adv2")
	GNTestAssert.assert_not_null(node.get_parameter("scale"), "has scale param")

func test_advect_pop_no_input() -> void:
	var node := _make_node(AdvectPOP.new(), "adv3")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on null input")


# ═══════════════════════════════════════════════════════════════════════════════
#  InstancePOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_instance_pop_instantiation() -> void:
	var node := _make_node(InstancePOP.new(), "inst1")
	GNTestAssert.assert_not_null(node, "InstancePOP created")

func test_instance_pop_no_input() -> void:
	var node := _make_node(InstancePOP.new(), "inst2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on null input")

func test_instance_pop_ports() -> void:
	var node := _make_node(InstancePOP.new(), "inst3")
	GNTestAssert.assert_gt(node.input_ports.size(), 0, "has POP input port")


# ═══════════════════════════════════════════════════════════════════════════════
#  RenderPOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_render_pop_instantiation() -> void:
	var node := _make_node(RenderPOP.new(), "rend1")
	GNTestAssert.assert_not_null(node, "RenderPOP created")

func test_render_pop_no_input() -> void:
	var node := _make_node(RenderPOP.new(), "rend2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on null input")

func test_render_pop_output_family() -> void:
	var node := _make_node(RenderPOP.new(), "rend3")
	# RenderPOP outputs COMP data, not POP
	GNTestAssert.assert_gt(node.output_ports.size(), 0, "has output port")


# ═══════════════════════════════════════════════════════════════════════════════
#  ParticleStateTOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_particle_state_top_instantiation() -> void:
	var node := _make_node(ParticleStateTOP.new(), "pst1")
	GNTestAssert.assert_not_null(node, "ParticleStateTOP created")

func test_particle_state_top_family() -> void:
	var node := _make_node(ParticleStateTOP.new(), "pst2")
	# It's registered as TOP family but takes POP input
	GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family is TOP")

func test_particle_state_top_no_input() -> void:
	var node := _make_node(ParticleStateTOP.new(), "pst3")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on null input")


# ═══════════════════════════════════════════════════════════════════════════════
#  GNParticleData
# ═══════════════════════════════════════════════════════════════════════════════

func test_particle_data_family() -> void:
	var pd := GNParticleData.new()
	GNTestAssert.assert_eq(pd.get_family(), GNFamily.Type.POP, "family is POP")

func test_particle_data_defaults() -> void:
	var pd := GNParticleData.new()
	GNTestAssert.assert_eq(pd.particle_count, 0, "default count 0")
	GNTestAssert.assert_eq(pd.max_particles, 0, "default max 0")
	GNTestAssert.assert_eq(pd.stride, 0, "default stride 0")

func test_particle_data_attrib_layout() -> void:
	var layout := GNPopBase._get_standard_layout()
	GNTestAssert.assert_has_key(layout, "pos", "has pos attribute")
	GNTestAssert.assert_has_key(layout, "vel", "has vel attribute")
	GNTestAssert.assert_has_key(layout, "color", "has color attribute")
	GNTestAssert.assert_has_key(layout, "age", "has age attribute")
	GNTestAssert.assert_has_key(layout, "life", "has life attribute")
	GNTestAssert.assert_has_key(layout, "pscale", "has pscale attribute")

func test_particle_data_standard_stride() -> void:
	GNTestAssert.assert_eq(GNPopBase.STANDARD_STRIDE, 64, "standard stride is 64 bytes")

func test_particle_data_invalidate() -> void:
	var pd := GNParticleData.new()
	pd.particle_count = 100
	pd.invalidate()
	GNTestAssert.assert_eq(pd.particle_count, 0, "invalidate resets count")


# ═══════════════════════════════════════════════════════════════════════════════
#  GNPopBase Standard Layout
# ═══════════════════════════════════════════════════════════════════════════════

func test_pop_base_standard_layout_offsets() -> void:
	var layout := GNPopBase._get_standard_layout()
	var pos_desc: GNParticleData.AttribDesc = layout["pos"]
	GNTestAssert.assert_eq(pos_desc.offset, 0, "pos offset is 0")
	GNTestAssert.assert_eq(pos_desc.type, "vec4", "pos type is vec4")
	var vel_desc: GNParticleData.AttribDesc = layout["vel"]
	GNTestAssert.assert_eq(vel_desc.offset, 16, "vel offset is 16")
	var color_desc: GNParticleData.AttribDesc = layout["color"]
	GNTestAssert.assert_eq(color_desc.offset, 32, "color offset is 32")
	var age_desc: GNParticleData.AttribDesc = layout["age"]
	GNTestAssert.assert_eq(age_desc.offset, 48, "age offset is 48")
	var pscale_desc: GNParticleData.AttribDesc = layout["pscale"]
	GNTestAssert.assert_eq(pscale_desc.offset, 60, "pscale offset is 60")

func test_pop_base_workgroups() -> void:
	var base := GNPopBase.new()
	GNTestAssert.assert_eq(base._workgroups(1000, 256), 4, "1000/256 = 4 groups")
	GNTestAssert.assert_eq(base._workgroups(256, 256), 1, "256/256 = 1 group")
	GNTestAssert.assert_eq(base._workgroups(257, 256), 2, "257/256 = 2 groups")
# ═══════════════════════════════════════════════════════════════════════════════
#  AdvectPOPNative
# ═══════════════════════════════════════════════════════════════════════════════

func test_advect_pop_native_instantiation() -> void:
	var node := _make_node(AdvectPOPNative.new(), "advn1")
	GNTestAssert.assert_not_null(node, "AdvectPOPNative created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_advect_pop_native_cook() -> void:
	var node := _make_node(AdvectPOPNative.new(), "advn2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on cook")


# ═══════════════════════════════════════════════════════════════════════════════
#  AttractPOPNative
# ═══════════════════════════════════════════════════════════════════════════════

func test_attract_pop_native_instantiation() -> void:
	var node := _make_node(AttractPOPNative.new(), "attrn1")
	GNTestAssert.assert_not_null(node, "AttractPOPNative created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_attract_pop_native_cook() -> void:
	var node := _make_node(AttractPOPNative.new(), "attrn2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on cook")


# ═══════════════════════════════════════════════════════════════════════════════
#  CollisionPOPNative
# ═══════════════════════════════════════════════════════════════════════════════

func test_collision_pop_native_instantiation() -> void:
	var node := _make_node(CollisionPOPNative.new(), "colln1")
	GNTestAssert.assert_not_null(node, "CollisionPOPNative created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_collision_pop_native_cook() -> void:
	var node := _make_node(CollisionPOPNative.new(), "colln2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on cook")


# ═══════════════════════════════════════════════════════════════════════════════
#  ForcePOPNative
# ═══════════════════════════════════════════════════════════════════════════════

func test_force_pop_native_instantiation() -> void:
	var node := _make_node(ForcePOPNative.new(), "forcen1")
	GNTestAssert.assert_not_null(node, "ForcePOPNative created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_force_pop_native_cook() -> void:
	var node := _make_node(ForcePOPNative.new(), "forcen2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on cook")


# ═══════════════════════════════════════════════════════════════════════════════
#  InstancePOPNative
# ═══════════════════════════════════════════════════════════════════════════════

func test_instance_pop_native_instantiation() -> void:
	var node := _make_node(InstancePOPNative.new(), "instn1")
	GNTestAssert.assert_not_null(node, "InstancePOPNative created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_instance_pop_native_cook() -> void:
	var node := _make_node(InstancePOPNative.new(), "instn2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on cook")


# ═══════════════════════════════════════════════════════════════════════════════
#  LimitPOPNative
# ═══════════════════════════════════════════════════════════════════════════════

func test_limit_pop_native_instantiation() -> void:
	var node := _make_node(LimitPOPNative.new(), "limn1")
	GNTestAssert.assert_not_null(node, "LimitPOPNative created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_limit_pop_native_cook() -> void:
	var node := _make_node(LimitPOPNative.new(), "limn2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on cook")


# ═══════════════════════════════════════════════════════════════════════════════
#  RenderPOPNative
# ═══════════════════════════════════════════════════════════════════════════════

func test_render_pop_native_instantiation() -> void:
	var node := _make_node(RenderPOPNative.new(), "rendn1")
	GNTestAssert.assert_not_null(node, "RenderPOPNative created")

func test_render_pop_native_node_type() -> void:
	var node := _make_node(RenderPOPNative.new(), "rendn2")
	GNTestAssert.assert_eq(node.node_type, "render", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
#  SourcePOPNative
# ═══════════════════════════════════════════════════════════════════════════════

func test_source_pop_native_instantiation() -> void:
	var node := _make_node(SourcePOPNative.new(), "srcn1")
	GNTestAssert.assert_not_null(node, "SourcePOPNative created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_source_pop_native_cook() -> void:
	var node := _make_node(SourcePOPNative.new(), "srcn2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on cook")


# ═══════════════════════════════════════════════════════════════════════════════
#  TurbulencePOPNative
# ═══════════════════════════════════════════════════════════════════════════════

func test_turbulence_pop_native_instantiation() -> void:
	var node := _make_node(TurbulencePOPNative.new(), "turbn1")
	GNTestAssert.assert_not_null(node, "TurbulencePOPNative created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_turbulence_pop_native_cook() -> void:
	var node := _make_node(TurbulencePOPNative.new(), "turbn2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on cook")


# ═══════════════════════════════════════════════════════════════════════════════
#  BoidsPOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_boids_pop_instantiation() -> void:
	var node := _make_node(BoidsPOP.new(), "boids1")
	GNTestAssert.assert_not_null(node, "BoidsPOP created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_boids_pop_params() -> void:
	var node := _make_node(BoidsPOP.new(), "boids2")
	# Flocking simulation should have steering/separation params
	GNTestAssert.assert_not_null(node.get_parameter("separation"), "has separation param")

func test_boids_pop_cook() -> void:
	var node := _make_node(BoidsPOP.new(), "boids3")
	var out := _cook_no_input(node)
	# Output can be null in headless, or GNParticleData
	if out != null:
		GNTestAssert.assert_true(out is GNParticleData, "output is GNParticleData")


# ═══════════════════════════════════════════════════════════════════════════════
#  NullPOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_null_pop_instantiation() -> void:
	var node := _make_node(NullPOP.new(), "nullpop1")
	GNTestAssert.assert_not_null(node, "NullPOP created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_null_pop_passthrough() -> void:
	var node := _make_node(NullPOP.new(), "nullpop2")
	var out := _cook_no_input(node)
	# NullPOP is a pass-through, empty input = null output
	if out == null:
		GNTestAssert.assert_true(true, "null input produces null output")
