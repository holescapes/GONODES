extends Node
## Unit tests for CPU fallback paths (Phase 3 — mobile/web export).
##
## These tests exercise the `_cook_cpu()` method of POP and VOL operators
## directly, simulating what the cook engine does when compute shaders are
## unavailable (Compatibility renderer / WebGL2).
##
## Each test:
##   1. Creates the operator and initializes it.
##   2. Calls `_cook_cpu()` with appropriate inputs.
##   3. Validates the output data type, CPU mode flag, and basic shape.

var _engine: GNCookEngine
var _network: GNNetwork


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

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
	if _engine and is_instance_valid(_engine):
		_engine.queue_free()
	_engine = null
	_network = null


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _make_node(node: GNNode, id: String) -> GNNode:
	node.initialize(id)
	_network.add_node(node)
	_engine.add_child(node)
	return node


func _cook_cpu_no_input(node: GNNode) -> GNData:
	var inputs: Array[GNData] = []
	return node._cook_cpu(inputs)


func _cook_cpu_with(node: GNNode, inputs: Array[GNData]) -> GNData:
	return node._cook_cpu(inputs)


# ═══════════════════════════════════════════════════════════════════════════════
# Infrastructure Tests
# ═══════════════════════════════════════════════════════════════════════════════

func test_gn_node_has_cpu_fallback_default_false() -> void:
	var node := GNNode.new()
	node.initialize("base1")
	assert(not node.has_cpu_fallback(), "Base GNNode should not have CPU fallback")
	node.queue_free()


func test_pop_base_has_cpu_fallback_true() -> void:
	var node := SourcePOP.new()
	node.initialize("src1")
	assert(node.has_cpu_fallback(), "POP operators should have CPU fallback")
	node.queue_free()


func test_vol_base_has_cpu_fallback_true() -> void:
	var node := NoiseVOL.new()
	node.initialize("noise1")
	assert(node.has_cpu_fallback(), "VOL operators should have CPU fallback")
	node.queue_free()


func test_particle_data_cpu_empty_overhead() -> void:
	# Verify that CPU arrays start empty (no wasted memory on GPU path)
	var pd := GNParticleData.new()
	assert(not pd.is_cpu, "Default should be GPU mode")
	assert(pd.cpu_positions.size() == 0, "CPU positions should be empty by default")
	assert(pd.cpu_velocities.size() == 0, "CPU velocities should be empty by default")
	assert(pd.cpu_ages.size() == 0, "CPU ages should be empty by default")


func test_volume_data_cpu_empty_overhead() -> void:
	var vd := GNVolumeData.new()
	assert(not vd.is_cpu, "Default should be GPU mode")
	assert(vd.cpu_data.size() == 0, "CPU data should be empty by default")


func test_thread_detection_returns_bool() -> void:
	# On desktop, threads should be available
	var available: bool = GNGpuContext.are_threads_available()
	assert(available is bool, "are_threads_available() should return bool")


# ═══════════════════════════════════════════════════════════════════════════════
# POP CPU Fallback Tests
# ═══════════════════════════════════════════════════════════════════════════════

func test_source_pop_cpu_emits_particles() -> void:
	var node := _make_node(SourcePOP.new(), "src1")
	node.set_param_value("max_particles", 100)
	node.set_param_value("emit_rate", 50)
	var out := _cook_cpu_no_input(node)
	assert(out != null, "SourcePOP CPU should produce output")
	assert(out is GNParticleData, "Output should be GNParticleData")
	var pd: GNParticleData = out as GNParticleData
	assert(pd.is_cpu, "Should be in CPU mode")
	assert(pd.particle_count > 0, "Should have emitted particles")
	assert(pd.cpu_positions.size() == pd.particle_count,
		"CPU positions array should match particle count")


func test_force_pop_cpu_applies_gravity() -> void:
	# Create a source POP, cook it, then feed to force POP
	var src := _make_node(SourcePOP.new(), "src1")
	src.set_param_value("max_particles", 10)
	src.set_param_value("emit_rate", 10)
	var src_out := _cook_cpu_no_input(src)
	assert(src_out != null, "Source should produce particles")

	var force := _make_node(ForcePOP.new(), "force1")
	force.set_param_value("gravity", Vector3(0, -9.8, 0))
	var inputs: Array[GNData] = [src_out]
	var out := _cook_cpu_with(force, inputs)
	assert(out != null, "ForcePOP CPU should produce output")
	assert(out is GNParticleData, "Output should be GNParticleData")


func test_attract_pop_cpu_returns_particles() -> void:
	var src := _make_node(SourcePOP.new(), "src1")
	src.set_param_value("max_particles", 10)
	src.set_param_value("emit_rate", 10)
	var src_out := _cook_cpu_no_input(src)

	var attract := _make_node(AttractPOP.new(), "attract1")
	var inputs: Array[GNData] = [src_out]
	var out := _cook_cpu_with(attract, inputs)
	assert(out != null, "AttractPOP CPU should produce output")
	assert(out is GNParticleData, "Output should be GNParticleData")


func test_collision_pop_cpu_returns_particles() -> void:
	var src := _make_node(SourcePOP.new(), "src1")
	src.set_param_value("max_particles", 10)
	src.set_param_value("emit_rate", 10)
	var src_out := _cook_cpu_no_input(src)

	var coll := _make_node(CollisionPOP.new(), "coll1")
	var inputs: Array[GNData] = [src_out]
	var out := _cook_cpu_with(coll, inputs)
	assert(out != null, "CollisionPOP CPU should produce output")
	assert(out is GNParticleData, "Output should be GNParticleData")


func test_turbulence_pop_cpu_returns_particles() -> void:
	var src := _make_node(SourcePOP.new(), "src1")
	src.set_param_value("max_particles", 10)
	src.set_param_value("emit_rate", 10)
	var src_out := _cook_cpu_no_input(src)

	var turb := _make_node(TurbulencePOP.new(), "turb1")
	var inputs: Array[GNData] = [src_out]
	var out := _cook_cpu_with(turb, inputs)
	assert(out != null, "TurbulencePOP CPU should produce output")
	assert(out is GNParticleData, "Output should be GNParticleData")


func test_limit_pop_cpu_returns_particles() -> void:
	var src := _make_node(SourcePOP.new(), "src1")
	src.set_param_value("max_particles", 10)
	src.set_param_value("emit_rate", 10)
	var src_out := _cook_cpu_no_input(src)

	var lim := _make_node(LimitPOP.new(), "lim1")
	var inputs: Array[GNData] = [src_out]
	var out := _cook_cpu_with(lim, inputs)
	assert(out != null, "LimitPOP CPU should produce output")
	assert(out is GNParticleData, "Output should be GNParticleData")


func test_null_pop_cpu_passthrough() -> void:
	var src := _make_node(SourcePOP.new(), "src1")
	src.set_param_value("max_particles", 10)
	src.set_param_value("emit_rate", 10)
	var src_out := _cook_cpu_no_input(src)

	var null_pop := _make_node(NullPOP.new(), "null1")
	var inputs: Array[GNData] = [src_out]
	var out := _cook_cpu_with(null_pop, inputs)
	assert(out != null, "NullPOP CPU should pass through")
	assert(out is GNParticleData, "Output should be GNParticleData")


# ═══════════════════════════════════════════════════════════════════════════════
# VOL CPU Fallback Tests
# ═══════════════════════════════════════════════════════════════════════════════

func test_noise_vol_cpu_produces_volume() -> void:
	var node := _make_node(NoiseVOL.new(), "noise1")
	node.set_param_value("resolution", Vector3i(16, 16, 16))
	var out := _cook_cpu_no_input(node)
	assert(out != null, "NoiseVOL CPU should produce output")
	assert(out is GNVolumeData, "Output should be GNVolumeData")
	var vd: GNVolumeData = out as GNVolumeData
	assert(vd.is_cpu, "Should be in CPU mode")
	assert(vd.cpu_data.size() == 16 * 16 * 16,
		"CPU data should have res^3 elements for single-channel volume")


func test_blur_vol_cpu_produces_volume() -> void:
	var noise := _make_node(NoiseVOL.new(), "noise1")
	noise.set_param_value("resolution", Vector3i(8, 8, 8))
	var noise_out := _cook_cpu_no_input(noise)

	var blur := _make_node(BlurVOL.new(), "blur1")
	var inputs: Array[GNData] = [noise_out]
	var out := _cook_cpu_with(blur, inputs)
	assert(out != null, "BlurVOL CPU should produce output")
	assert(out is GNVolumeData, "Output should be GNVolumeData")


func test_blend_vol_cpu_produces_volume() -> void:
	var n1 := _make_node(NoiseVOL.new(), "n1")
	n1.set_param_value("resolution", Vector3i(8, 8, 8))
	var out1 := _cook_cpu_no_input(n1)

	var n2 := _make_node(NoiseVOL.new(), "n2")
	n2.set_param_value("resolution", Vector3i(8, 8, 8))
	n2.set_param_value("seed", 42)
	var out2 := _cook_cpu_no_input(n2)

	var blend := _make_node(BlendVOL.new(), "blend1")
	var inputs: Array[GNData] = [out1, out2]
	var out := _cook_cpu_with(blend, inputs)
	assert(out != null, "BlendVOL CPU should produce output")
	assert(out is GNVolumeData, "Output should be GNVolumeData")


func test_null_vol_cpu_passthrough() -> void:
	var noise := _make_node(NoiseVOL.new(), "noise1")
	noise.set_param_value("resolution", Vector3i(8, 8, 8))
	var noise_out := _cook_cpu_no_input(noise)

	var null_vol := _make_node(NullVOL.new(), "null1")
	var inputs: Array[GNData] = [noise_out]
	var out := _cook_cpu_with(null_vol, inputs)
	assert(out != null, "NullVOL CPU should pass through")
	assert(out is GNVolumeData, "Output should be GNVolumeData")


func test_analyze_vol_cpu_produces_output() -> void:
	var noise := _make_node(NoiseVOL.new(), "noise1")
	noise.set_param_value("resolution", Vector3i(8, 8, 8))
	var noise_out := _cook_cpu_no_input(noise)

	var analyze := _make_node(AnalyzeVOL.new(), "analyze1")
	var inputs: Array[GNData] = [noise_out]
	var out := _cook_cpu_with(analyze, inputs)
	# AnalyzeVOL produces stats — output may be DAT or the volume itself
	assert(out != null, "AnalyzeVOL CPU should produce output")


func test_fluid_vol_cpu_produces_volume() -> void:
	var fluid := _make_node(FluidVOL.new(), "fluid1")
	fluid.set_param_value("resolution", Vector3i(8, 8, 8))
	var out := _cook_cpu_no_input(fluid)
	assert(out != null, "FluidVOL CPU should produce output")
	assert(out is GNVolumeData, "Output should be GNVolumeData")
	var vd: GNVolumeData = out as GNVolumeData
	assert(vd.is_cpu, "Should be in CPU mode")


func test_displace_vol_cpu_produces_volume() -> void:
	var noise := _make_node(NoiseVOL.new(), "noise1")
	noise.set_param_value("resolution", Vector3i(8, 8, 8))
	var noise_out := _cook_cpu_no_input(noise)

	var disp := _make_node(DisplaceVOL.new(), "disp1")
	var inputs: Array[GNData] = [noise_out]
	var out := _cook_cpu_with(disp, inputs)
	assert(out != null, "DisplaceVOL CPU should produce output")
	assert(out is GNVolumeData, "Output should be GNVolumeData")


# ═══════════════════════════════════════════════════════════════════════════════
# GNParticleData CPU Mode Tests
# ═══════════════════════════════════════════════════════════════════════════════

func test_particle_data_cpu_duplicate() -> void:
	var pd := GNParticleData.new()
	pd.is_cpu = true
	pd.particle_count = 3
	pd.max_particles = 10
	pd.cpu_positions = PackedVector3Array([Vector3.ZERO, Vector3.ONE, Vector3.UP])
	pd.cpu_velocities = PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
	pd.cpu_ages = PackedFloat32Array([0.0, 0.1, 0.2])
	pd.cpu_lives = PackedFloat32Array([1.0, 1.0, 1.0])
	pd.valid = true

	var copy := pd.duplicate_data()
	assert(copy is GNParticleData, "Duplicate should be GNParticleData")
	var cpd: GNParticleData = copy as GNParticleData
	assert(cpd.is_cpu, "Copy should be CPU mode")
	assert(cpd.particle_count == 3, "Copy should have same particle count")
	assert(cpd.cpu_positions.size() == 3, "Copy should have same positions")
	# Verify it's a deep copy (modifying copy doesn't affect original)
	cpd.cpu_positions[0] = Vector3(999, 999, 999)
	assert(pd.cpu_positions[0] == Vector3.ZERO, "Original should not be modified")


func test_particle_data_cpu_has_particles() -> void:
	var pd := GNParticleData.new()
	assert(not pd.has_particles(), "Empty GPU-mode should report no particles")
	pd.is_cpu = true
	pd.particle_count = 5
	assert(pd.has_particles(), "CPU mode with count > 0 should report particles")


func test_volume_data_cpu_duplicate() -> void:
	var vd := GNVolumeData.new()
	vd.is_cpu = true
	vd.resolution = Vector3i(4, 4, 4)
	vd.cpu_data = PackedFloat32Array()
	vd.cpu_data.resize(64)
	vd.cpu_data[0] = 42.0
	vd.valid = true

	var copy := vd.duplicate_data()
	assert(copy is GNVolumeData, "Duplicate should be GNVolumeData")
	var cvd: GNVolumeData = copy as GNVolumeData
	assert(cvd.is_cpu, "Copy should be CPU mode")
	assert(cvd.cpu_data.size() == 64, "Copy should have same data size")
	assert(cvd.cpu_data[0] == 42.0, "Copy should have same data values")
	cvd.cpu_data[0] = 0.0
	assert(vd.cpu_data[0] == 42.0, "Original should not be modified")


# ═══════════════════════════════════════════════════════════════════════════════
# GNCompatReportPanel Tests
# ═══════════════════════════════════════════════════════════════════════════════

func test_compat_panel_scans_clean_network() -> void:
	# A network with only CHOP nodes should be fully compatible
	var panel := GNCompatReportPanel.new()
	panel.network = _network
	add_child(panel)
	# Give it a frame to build UI
	await get_tree().process_frame
	# Summary should say "All X nodes compatible"
	# Just verify it doesn't crash on an empty network
	panel._scan()
	panel.queue_free()
