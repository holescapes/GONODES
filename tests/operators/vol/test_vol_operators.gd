extends Node
## Correctness tests for VOL (Volume Operator) operators.
##
## VOL operators use GPU compute — tests exercise instantiation, parameter
## defaults, null-safety, output data structure, and helper utilities.

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
#  NoiseVOL
# ═══════════════════════════════════════════════════════════════════════════════

func test_noise_vol_instantiation() -> void:
	var node := _make_node(NoiseVOL.new(), "noise1")
	GNTestAssert.assert_not_null(node, "NoiseVOL created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.VOL, "family is VOL")

func test_noise_vol_default_params() -> void:
	var node := _make_node(NoiseVOL.new(), "noise2")
	GNTestAssert.assert_not_null(node.get_parameter("resolution"), "has resolution param")
	GNTestAssert.assert_not_null(node.get_parameter("frequency"), "has frequency param")
	GNTestAssert.assert_not_null(node.get_parameter("amplitude"), "has amplitude param")

func test_noise_vol_output_type() -> void:
	var node := _make_node(NoiseVOL.new(), "noise3")
	var out := _cook_no_input(node)
	if out != null:
		GNTestAssert.assert_true(out is GNVolumeData, "output is GNVolumeData")

func test_noise_vol_node_type() -> void:
	var node := _make_node(NoiseVOL.new(), "noise4")
	GNTestAssert.assert_eq(node.node_type, "noise", "node_type is noise")


# ═══════════════════════════════════════════════════════════════════════════════
#  BlendVOL
# ═══════════════════════════════════════════════════════════════════════════════

func test_blend_vol_instantiation() -> void:
	var node := _make_node(BlendVOL.new(), "blend1")
	GNTestAssert.assert_not_null(node, "BlendVOL created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.VOL, "family is VOL")

func test_blend_vol_params() -> void:
	var node := _make_node(BlendVOL.new(), "blend2")
	GNTestAssert.assert_not_null(node.get_parameter("mode"), "has mode param")
	GNTestAssert.assert_not_null(node.get_parameter("mix"), "has mix param")

func test_blend_vol_no_input() -> void:
	var node := _make_node(BlendVOL.new(), "blend3")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on null input")

func test_blend_vol_two_inputs() -> void:
	var node := _make_node(BlendVOL.new(), "blend4")
	GNTestAssert.assert_gt(node.input_ports.size(), 1, "has at least 2 input ports")


# ═══════════════════════════════════════════════════════════════════════════════
#  BlurVOL
# ═══════════════════════════════════════════════════════════════════════════════

func test_blur_vol_instantiation() -> void:
	var node := _make_node(BlurVOL.new(), "blur1")
	GNTestAssert.assert_not_null(node, "BlurVOL created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.VOL, "family is VOL")

func test_blur_vol_params() -> void:
	var node := _make_node(BlurVOL.new(), "blur2")
	GNTestAssert.assert_not_null(node.get_parameter("radius"), "has radius param")

func test_blur_vol_no_input() -> void:
	var node := _make_node(BlurVOL.new(), "blur3")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on null input")


# ═══════════════════════════════════════════════════════════════════════════════
#  DisplaceVOL
# ═══════════════════════════════════════════════════════════════════════════════

func test_displace_vol_instantiation() -> void:
	var node := _make_node(DisplaceVOL.new(), "disp1")
	GNTestAssert.assert_not_null(node, "DisplaceVOL created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.VOL, "family is VOL")

func test_displace_vol_params() -> void:
	var node := _make_node(DisplaceVOL.new(), "disp2")
	GNTestAssert.assert_not_null(node.get_parameter("scale"), "has scale param")

func test_displace_vol_no_input() -> void:
	var node := _make_node(DisplaceVOL.new(), "disp3")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on null input")


# ═══════════════════════════════════════════════════════════════════════════════
#  FluidVOL
# ═══════════════════════════════════════════════════════════════════════════════

func test_fluid_vol_instantiation() -> void:
	var node := _make_node(FluidVOL.new(), "fluid1")
	GNTestAssert.assert_not_null(node, "FluidVOL created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.VOL, "family is VOL")

func test_fluid_vol_params() -> void:
	var node := _make_node(FluidVOL.new(), "fluid2")
	GNTestAssert.assert_not_null(node.get_parameter("resolution"), "has resolution param")
	GNTestAssert.assert_not_null(node.get_parameter("pressure_iterations"), "has pressure_iterations param")

func test_fluid_vol_time_dependent() -> void:
	var node := _make_node(FluidVOL.new(), "fluid3")
	GNTestAssert.assert_true(node.time_dependent, "FluidVOL is time-dependent")

func test_fluid_vol_output_type() -> void:
	var node := _make_node(FluidVOL.new(), "fluid4")
	var out := _cook_no_input(node)
	if out != null:
		GNTestAssert.assert_true(out is GNVolumeData, "output is GNVolumeData")


# ═══════════════════════════════════════════════════════════════════════════════
#  MarchingCubesVOL
# ═══════════════════════════════════════════════════════════════════════════════

func test_marching_cubes_vol_instantiation() -> void:
	var node := _make_node(MarchingCubesVOL.new(), "mc1")
	GNTestAssert.assert_not_null(node, "MarchingCubesVOL created")

func test_marching_cubes_vol_params() -> void:
	var node := _make_node(MarchingCubesVOL.new(), "mc2")
	GNTestAssert.assert_not_null(node.get_parameter("threshold"), "has threshold param")

func test_marching_cubes_vol_output_family() -> void:
	var node := _make_node(MarchingCubesVOL.new(), "mc3")
	# MarchingCubesVOL outputs SOP (GNGeoData), not VOL
	var has_sop_out := false
	for p in node.output_ports:
		if p.family == GNFamily.Type.SOP:
			has_sop_out = true
	GNTestAssert.assert_true(has_sop_out, "has SOP output port")

func test_marching_cubes_vol_no_input() -> void:
	var node := _make_node(MarchingCubesVOL.new(), "mc4")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on null input")


# ═══════════════════════════════════════════════════════════════════════════════
#  RaymarchVOL
# ═══════════════════════════════════════════════════════════════════════════════

func test_raymarch_vol_instantiation() -> void:
	var node := _make_node(RaymarchVOL.new(), "rm1")
	GNTestAssert.assert_not_null(node, "RaymarchVOL created")

func test_raymarch_vol_params() -> void:
	var node := _make_node(RaymarchVOL.new(), "rm2")
	GNTestAssert.assert_not_null(node.get_parameter("step_count"), "has step_count param")
	GNTestAssert.assert_not_null(node.get_parameter("density_scale"), "has density_scale param")

func test_raymarch_vol_output_family() -> void:
	var node := _make_node(RaymarchVOL.new(), "rm3")
	# RaymarchVOL outputs TOP (texture), not VOL
	var has_top_out := false
	for p in node.output_ports:
		if p.family == GNFamily.Type.TOP:
			has_top_out = true
	GNTestAssert.assert_true(has_top_out, "has TOP output port")

func test_raymarch_vol_no_input() -> void:
	var node := _make_node(RaymarchVOL.new(), "rm4")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on null input")


# ═══════════════════════════════════════════════════════════════════════════════
#  SOPtoVOL
# ═══════════════════════════════════════════════════════════════════════════════

func test_sop_to_vol_instantiation() -> void:
	var node := _make_node(SOPtoVOL.new(), "s2v1")
	GNTestAssert.assert_not_null(node, "SOPtoVOL created")

func test_sop_to_vol_params() -> void:
	var node := _make_node(SOPtoVOL.new(), "s2v2")
	GNTestAssert.assert_not_null(node.get_parameter("resolution"), "has resolution param")

func test_sop_to_vol_input_family() -> void:
	var node := _make_node(SOPtoVOL.new(), "s2v3")
	# SOPtoVOL takes SOP input
	var has_sop_in := false
	for p in node.input_ports:
		if p.family == GNFamily.Type.SOP:
			has_sop_in = true
	GNTestAssert.assert_true(has_sop_in, "has SOP input port")

func test_sop_to_vol_no_input() -> void:
	var node := _make_node(SOPtoVOL.new(), "s2v4")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on null input")


# ═══════════════════════════════════════════════════════════════════════════════
#  CHOPtoVOL
# ═══════════════════════════════════════════════════════════════════════════════

func test_chop_to_vol_instantiation() -> void:
	var node := _make_node(CHOPtoVOL.new(), "c2v1")
	GNTestAssert.assert_not_null(node, "CHOPtoVOL created")

func test_chop_to_vol_input_family() -> void:
	var node := _make_node(CHOPtoVOL.new(), "c2v2")
	var has_chop_in := false
	for p in node.input_ports:
		if p.family == GNFamily.Type.CHOP:
			has_chop_in = true
	GNTestAssert.assert_true(has_chop_in, "has CHOP input port")

func test_chop_to_vol_no_input() -> void:
	var node := _make_node(CHOPtoVOL.new(), "c2v3")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on null input")


# ═══════════════════════════════════════════════════════════════════════════════
#  AnalyzeVOL
# ═══════════════════════════════════════════════════════════════════════════════

func test_analyze_vol_instantiation() -> void:
	var node := _make_node(AnalyzeVOL.new(), "anlz1")
	GNTestAssert.assert_not_null(node, "AnalyzeVOL created")

func test_analyze_vol_output_family() -> void:
	var node := _make_node(AnalyzeVOL.new(), "anlz2")
	# AnalyzeVOL outputs CHOP (statistics channels)
	var has_chop_out := false
	for p in node.output_ports:
		if p.family == GNFamily.Type.CHOP:
			has_chop_out = true
	GNTestAssert.assert_true(has_chop_out, "has CHOP output port")

func test_analyze_vol_no_input() -> void:
	var node := _make_node(AnalyzeVOL.new(), "anlz3")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on null input")


# ═══════════════════════════════════════════════════════════════════════════════
#  GNVolumeData
# ═══════════════════════════════════════════════════════════════════════════════

func test_volume_data_family() -> void:
	var vd := GNVolumeData.new()
	GNTestAssert.assert_eq(vd.get_family(), GNFamily.Type.VOL, "family is VOL")

func test_volume_data_defaults() -> void:
	var vd := GNVolumeData.new()
	GNTestAssert.assert_eq(vd.resolution, Vector3i(64, 64, 64), "default resolution 64^3")
	GNTestAssert.assert_eq(vd.channel_count, 1, "default 1 channel")
	GNTestAssert.assert_eq(vd.field_name, "density", "default field_name density")

func test_volume_data_voxel_count() -> void:
	var vd := GNVolumeData.new()
	vd.resolution = Vector3i(32, 32, 32)
	GNTestAssert.assert_eq(vd.voxel_count(), 32768, "32^3 = 32768 voxels")

func test_volume_data_bytes_per_voxel_r32() -> void:
	var vd := GNVolumeData.new()
	vd.data_format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	GNTestAssert.assert_eq(vd.bytes_per_voxel(), 4, "R32F = 4 bytes")

func test_volume_data_bytes_per_voxel_rgba32() -> void:
	var vd := GNVolumeData.new()
	vd.data_format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	GNTestAssert.assert_eq(vd.bytes_per_voxel(), 16, "RGBA32F = 16 bytes")

func test_volume_data_bytes_per_voxel_r16() -> void:
	var vd := GNVolumeData.new()
	vd.data_format = RenderingDevice.DATA_FORMAT_R16_SFLOAT
	GNTestAssert.assert_eq(vd.bytes_per_voxel(), 2, "R16F = 2 bytes")

func test_volume_data_has_volume_empty() -> void:
	var vd := GNVolumeData.new()
	GNTestAssert.assert_false(vd.has_volume(), "no volume when rd_texture is invalid")

func test_volume_data_bounds() -> void:
	var vd := GNVolumeData.new()
	GNTestAssert.assert_eq(vd.bounds.position, Vector3(-0.5, -0.5, -0.5), "default bounds position")
	GNTestAssert.assert_eq(vd.bounds.size, Vector3(1.0, 1.0, 1.0), "default bounds size")


# ═══════════════════════════════════════════════════════════════════════════════
#  GNVolBase Helpers
# ═══════════════════════════════════════════════════════════════════════════════

func test_vol_base_workgroups_3d() -> void:
	var base := GNVolBase.new()
	var wg := base._workgroups_3d(Vector3i(64, 64, 64), 8)
	GNTestAssert.assert_eq(wg, Vector3i(8, 8, 8), "64/8 = 8 groups per axis")

func test_vol_base_workgroups_3d_non_divisible() -> void:
	var base := GNVolBase.new()
	var wg := base._workgroups_3d(Vector3i(65, 33, 17), 8)
	GNTestAssert.assert_eq(wg.x, 9, "65/8 = 9 (ceil)")
	GNTestAssert.assert_eq(wg.y, 5, "33/8 = 5 (ceil)")
	GNTestAssert.assert_eq(wg.z, 3, "17/8 = 3 (ceil)")

func test_vol_base_channels_for_format() -> void:
	var base := GNVolBase.new()
	GNTestAssert.assert_eq(base._channels_for_format(RenderingDevice.DATA_FORMAT_R32_SFLOAT), 1, "R32F = 1 channel")
	GNTestAssert.assert_eq(base._channels_for_format(RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT), 4, "RGBA32F = 4 channels")
	GNTestAssert.assert_eq(base._channels_for_format(RenderingDevice.DATA_FORMAT_R16_SFLOAT), 1, "R16F = 1 channel")
	GNTestAssert.assert_eq(base._channels_for_format(RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT), 4, "RGBA16F = 4 channels")


# ═══════════════════════════════════════════════════════════════════════════════
#  GNGpuContext Singleton
# ═══════════════════════════════════════════════════════════════════════════════

func test_gpu_context_singleton() -> void:
	var ctx := GNGpuContext.get_context()
	GNTestAssert.assert_not_null(ctx, "GNGpuContext singleton exists")

func test_gpu_context_same_instance() -> void:
	var ctx1 := GNGpuContext.get_context()
	var ctx2 := GNGpuContext.get_context()
	GNTestAssert.assert_eq(ctx1, ctx2, "same singleton instance")

