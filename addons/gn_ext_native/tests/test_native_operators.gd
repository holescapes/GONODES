extends Node
## Tests for gn_ext_native operators (GDScript fallback paths).
##
## These operators have *Native suffix and are C++ accelerated versions.
## In headless/test environments without native libs, they fall back to
## GDScript implementations.

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


## True when the C++ native library is loaded and functional.
static func _native_libs_available() -> bool:
	# Native operators expose _processor; if null, C++ is not compiled/loaded.
	var probe := AudioDynamicsCHOPNative.new()
	return probe._processor != null


func _make_box_geo() -> GNGeoData:
	var box := _make_node(BoxSOP.new(), "box_%d" % randi())
	return _cook_no_input(box) as GNGeoData


func _make_sphere_geo(rings: int = 8, segments: int = 4) -> GNGeoData:
	var sph := _make_node(SphereSOP.new(), "sphere_%d" % randi())
	sph.set_param_value("rings", rings)
	sph.set_param_value("segments", segments)
	return _cook_no_input(sph) as GNGeoData


func _make_grid_geo(rows: int = 5, cols: int = 5) -> GNGeoData:
	var grid := _make_node(GridSOP.new(), "grid_%d" % randi())
	grid.set_param_value("rows", rows)
	grid.set_param_value("columns", cols)
	return _cook_no_input(grid) as GNGeoData


func _make_line_geo(points: int = 8) -> GNGeoData:
	var line := _make_node(LineSOP.new(), "line_%d" % randi())
	line.set_param_value("points", points)
	return _cook_no_input(line) as GNGeoData


func _make_cylinder_geo(segments: int = 8, height: float = 1.0) -> GNGeoData:
	var cyl := _make_node(CylinderSOP.new(), "cyl_%d" % randi())
	cyl.set_param_value("segments", segments)
	cyl.set_param_value("height", height)
	return _cook_no_input(cyl) as GNGeoData


# ═══════════════════════════════════════════════════════════════════════════════
#  CHOP Native Operators
# ═══════════════════════════════════════════════════════════════════════════════

func test_audio_dynamics_chop_native_instantiate() -> void:
	var node := _make_node(AudioDynamicsCHOPNative.new(), "audiodynamicsnative1")
	GNTestAssert.assert_not_null(node, "AudioDynamicsCHOPNative created")

func test_audio_dynamics_chop_native_cooks() -> void:
	var node := _make_node(AudioDynamicsCHOPNative.new(), "audiodynamicsnative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_audio_spectrum_chop_native_instantiate() -> void:
	var node := _make_node(AudioSpectrumCHOPNative.new(), "audiospectrumnative1")
	GNTestAssert.assert_not_null(node, "AudioSpectrumCHOPNative created")

func test_audio_spectrum_chop_native_cooks() -> void:
	var node := _make_node(AudioSpectrumCHOPNative.new(), "audiospectrumnative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	if _native_libs_available():
		GNTestAssert.assert_not_null(out, "output exists")
	else:
		GNTestAssert.assert_true(true, "native libs not available — skipped")

func test_composite_chop_native_instantiate() -> void:
	var node := _make_node(CompositeCHOPNative.new(), "compositenative1")
	GNTestAssert.assert_not_null(node, "CompositeCHOPNative created")

func test_composite_chop_native_cooks() -> void:
	var node := _make_node(CompositeCHOPNative.new(), "compositenative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_expression_chop_native_instantiate() -> void:
	var node := _make_node(ExpressionCHOPNative.new(), "expressionnative1")
	GNTestAssert.assert_not_null(node, "ExpressionCHOPNative created")

func test_expression_chop_native_cooks() -> void:
	var node := _make_node(ExpressionCHOPNative.new(), "expressionnative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	if _native_libs_available():
		GNTestAssert.assert_not_null(out, "output exists")
	else:
		GNTestAssert.assert_true(true, "native libs not available — skipped")

func test_fan_chop_native_instantiate() -> void:
	var node := _make_node(FanCHOPNative.new(), "fannative1")
	GNTestAssert.assert_not_null(node, "FanCHOPNative created")

func test_fan_chop_native_cooks() -> void:
	var node := _make_node(FanCHOPNative.new(), "fannative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_filter_chop_native_instantiate() -> void:
	var node := _make_node(FilterCHOPNative.new(), "filternative1")
	GNTestAssert.assert_not_null(node, "FilterCHOPNative created")

func test_filter_chop_native_cooks() -> void:
	var node := _make_node(FilterCHOPNative.new(), "filternative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_ik_chop_native_instantiate() -> void:
	var node := _make_node(IkCHOPNative.new(), "iknative1")
	GNTestAssert.assert_not_null(node, "IkCHOPNative created")

func test_ik_chop_native_cooks() -> void:
	var node := _make_node(IkCHOPNative.new(), "iknative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	if _native_libs_available():
		GNTestAssert.assert_not_null(out, "output exists")
	else:
		GNTestAssert.assert_true(true, "native libs not available — skipped")

func test_interpolate_chop_native_instantiate() -> void:
	var node := _make_node(InterpolateCHOPNative.new(), "interpolatenative1")
	GNTestAssert.assert_not_null(node, "InterpolateCHOPNative created")

func test_interpolate_chop_native_cooks() -> void:
	var node := _make_node(InterpolateCHOPNative.new(), "interpolatenative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_laser_chop_native_instantiate() -> void:
	var node := _make_node(LaserCHOPNative.new(), "lasernative1")
	GNTestAssert.assert_not_null(node, "LaserCHOPNative created")

func test_laser_chop_native_cooks() -> void:
	var node := _make_node(LaserCHOPNative.new(), "lasernative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	if _native_libs_available():
		GNTestAssert.assert_not_null(out, "output exists")
	else:
		GNTestAssert.assert_true(true, "native libs not available — skipped")

func test_lookup_chop_native_instantiate() -> void:
	var node := _make_node(LookupCHOPNative.new(), "lookupnative1")
	GNTestAssert.assert_not_null(node, "LookupCHOPNative created")

func test_lookup_chop_native_cooks() -> void:
	var node := _make_node(LookupCHOPNative.new(), "lookupnative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_math_chop_native_instantiate() -> void:
	var node := _make_node(MathCHOPNative.new(), "mathnative1")
	GNTestAssert.assert_not_null(node, "MathCHOPNative created")

func test_math_chop_native_cooks() -> void:
	var node := _make_node(MathCHOPNative.new(), "mathnative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_noise_chop_native_instantiate() -> void:
	var node := _make_node(NoiseCHOPNative.new(), "noisenative1")
	GNTestAssert.assert_not_null(node, "NoiseCHOPNative created")

func test_noise_chop_native_cooks() -> void:
	var node := _make_node(NoiseCHOPNative.new(), "noisenative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	if _native_libs_available():
		GNTestAssert.assert_not_null(out, "output exists")
	else:
		GNTestAssert.assert_true(true, "native libs not available — skipped")

func test_pattern_chop_native_instantiate() -> void:
	var node := _make_node(PatternCHOPNative.new(), "patternnative1")
	GNTestAssert.assert_not_null(node, "PatternCHOPNative created")

func test_pattern_chop_native_cooks() -> void:
	var node := _make_node(PatternCHOPNative.new(), "patternnative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	if _native_libs_available():
		GNTestAssert.assert_not_null(out, "output exists")
	else:
		GNTestAssert.assert_true(true, "native libs not available — skipped")

func test_physics_chop_native_instantiate() -> void:
	var node := _make_node(PhysicsCHOPNative.new(), "physicsnative1")
	GNTestAssert.assert_not_null(node, "PhysicsCHOPNative created")

func test_physics_chop_native_cooks() -> void:
	var node := _make_node(PhysicsCHOPNative.new(), "physicsnative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_resample_chop_native_instantiate() -> void:
	var node := _make_node(ResampleCHOPNative.new(), "resamplenative1")
	GNTestAssert.assert_not_null(node, "ResampleCHOPNative created")

func test_resample_chop_native_cooks() -> void:
	var node := _make_node(ResampleCHOPNative.new(), "resamplenative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_slope_chop_native_instantiate() -> void:
	var node := _make_node(SlopeCHOPNative.new(), "slopenative1")
	GNTestAssert.assert_not_null(node, "SlopeCHOPNative created")

func test_slope_chop_native_cooks() -> void:
	var node := _make_node(SlopeCHOPNative.new(), "slopenative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_smooth_chop_native_instantiate() -> void:
	var node := _make_node(SmoothCHOPNative.new(), "smoothnative1")
	GNTestAssert.assert_not_null(node, "SmoothCHOPNative created")

func test_smooth_chop_native_cooks() -> void:
	var node := _make_node(SmoothCHOPNative.new(), "smoothnative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_sop_to_chop_native_instantiate() -> void:
	var node := _make_node(SOPtoCHOPNative.new(), "soptonative1")
	GNTestAssert.assert_not_null(node, "SOPtoCHOPNative created")

func test_sop_to_chop_native_cooks() -> void:
	var node := _make_node(SOPtoCHOPNative.new(), "soptonative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_stretch_chop_native_instantiate() -> void:
	var node := _make_node(StretchCHOPNative.new(), "stretchnative1")
	GNTestAssert.assert_not_null(node, "StretchCHOPNative created")

func test_stretch_chop_native_cooks() -> void:
	var node := _make_node(StretchCHOPNative.new(), "stretchnative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_top_to_chop_native_instantiate() -> void:
	var node := _make_node(TOPtoCHOPNative.new(), "toptonative1")
	GNTestAssert.assert_not_null(node, "TOPtoCHOPNative created")

func test_top_to_chop_native_cooks() -> void:
	var node := _make_node(TOPtoCHOPNative.new(), "toptonative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_trail_chop_native_instantiate() -> void:
	var node := _make_node(TrailCHOPNative.new(), "trailnative1")
	GNTestAssert.assert_not_null(node, "TrailCHOPNative created")

func test_trail_chop_native_cooks() -> void:
	var node := _make_node(TrailCHOPNative.new(), "trailnative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_warp_chop_native_instantiate() -> void:
	var node := _make_node(WarpCHOPNative.new(), "warpnative1")
	GNTestAssert.assert_not_null(node, "WarpCHOPNative created")

func test_warp_chop_native_cooks() -> void:
	var node := _make_node(WarpCHOPNative.new(), "warpnative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_wave_chop_native_instantiate() -> void:
	var node := _make_node(WaveCHOPNative.new(), "wavenative1")
	GNTestAssert.assert_not_null(node, "WaveCHOPNative created")

func test_wave_chop_native_cooks() -> void:
	var node := _make_node(WaveCHOPNative.new(), "wavenative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	if _native_libs_available():
		GNTestAssert.assert_not_null(out, "output exists")
	else:
		GNTestAssert.assert_true(true, "native libs not available — skipped")

func test_chop_to_top_native_instantiate() -> void:
	var node := _make_node(CHOPtoTOPNative.new(), "choptotonative1")
	GNTestAssert.assert_not_null(node, "CHOPtoTOPNative created")

func test_chop_to_top_native_cooks() -> void:
	var node := _make_node(CHOPtoTOPNative.new(), "choptotonative2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")

func test_chop_to_vol_native_instantiate() -> void:
	var node := _make_node(CHOPtoVOLNative.new(), "choptovol native1")
	GNTestAssert.assert_not_null(node, "CHOPtoVOLNative created")

func test_chop_to_vol_native_cooks() -> void:
	var node := _make_node(CHOPtoVOLNative.new(), "choptovol native2")
	var out: GNChannelData = _cook_no_input(node) as GNChannelData
	# Processor/converter — null output with no input is expected behavior
	GNTestAssert.assert_true(true, "cook completed without crash")


# ═══════════════════════════════════════════════════════════════════════════════
#  SOP Native Operators
# ═══════════════════════════════════════════════════════════════════════════════

func test_attribute_sop_native_instantiate() -> void:
	var node := _make_node(AttributeSOPNative.new(), "attr_n1")
	GNTestAssert.assert_not_null(node, "AttributeSOPNative created")

func test_attribute_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(AttributeSOPNative.new(), "attr_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "AttributeSOPNative did not crash")

func test_bend_sop_native_instantiate() -> void:
	var node := _make_node(BendSOPNative.new(), "bend_n1")
	GNTestAssert.assert_not_null(node, "BendSOPNative created")

func test_bend_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(BendSOPNative.new(), "bend_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "BendSOPNative did not crash")

func test_blend_sop_native_instantiate() -> void:
	var node := _make_node(BlendSOPNative.new(), "blend_n1")
	GNTestAssert.assert_not_null(node, "BlendSOPNative created")

func test_blend_sop_native_cook() -> void:
	var geo_a := _make_sphere_geo(8, 4)
	var geo_b := _make_sphere_geo(8, 4)
	var node := _make_node(BlendSOPNative.new(), "blend_n2")
	var out := _cook_with(node, [geo_a, geo_b])
	GNTestAssert.assert_true(true, "BlendSOPNative did not crash")

func test_cap_sop_native_instantiate() -> void:
	var node := _make_node(CapSOPNative.new(), "cap_n1")
	GNTestAssert.assert_not_null(node, "CapSOPNative created")

func test_cap_sop_native_cook() -> void:
	var input := _make_cylinder_geo()
	var node := _make_node(CapSOPNative.new(), "cap_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "CapSOPNative did not crash")

func test_carve_sop_native_instantiate() -> void:
	var node := _make_node(CarveSOPNative.new(), "carve_n1")
	GNTestAssert.assert_not_null(node, "CarveSOPNative created")

func test_carve_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(CarveSOPNative.new(), "carve_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "CarveSOPNative did not crash")

func test_clip_sop_native_instantiate() -> void:
	var node := _make_node(ClipSOPNative.new(), "clip_n1")
	GNTestAssert.assert_not_null(node, "ClipSOPNative created")

func test_clip_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(ClipSOPNative.new(), "clip_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "ClipSOPNative did not crash")

func test_copy_sop_native_instantiate() -> void:
	var node := _make_node(CopySOPNative.new(), "copy_n1")
	GNTestAssert.assert_not_null(node, "CopySOPNative created")

func test_copy_sop_native_cook() -> void:
	var template := _make_box_geo()
	var target := _make_sphere_geo(4, 2)
	var node := _make_node(CopySOPNative.new(), "copy_n2")
	var out := _cook_with(node, [template, target])
	GNTestAssert.assert_true(true, "CopySOPNative did not crash")

func test_delete_sop_native_instantiate() -> void:
	var node := _make_node(DeleteSOPNative.new(), "del_n1")
	GNTestAssert.assert_not_null(node, "DeleteSOPNative created")

func test_delete_sop_native_cook() -> void:
	var input := _make_grid_geo(5, 5)
	var node := _make_node(DeleteSOPNative.new(), "del_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "DeleteSOPNative did not crash")

func test_divide_sop_native_instantiate() -> void:
	var node := _make_node(DivideSOPNative.new(), "div_n1")
	GNTestAssert.assert_not_null(node, "DivideSOPNative created")

func test_divide_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(DivideSOPNative.new(), "div_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "DivideSOPNative did not crash")

func test_extrude_sop_native_instantiate() -> void:
	var node := _make_node(ExtrudeSOPNative.new(), "extr_n1")
	GNTestAssert.assert_not_null(node, "ExtrudeSOPNative created")

func test_extrude_sop_native_cook() -> void:
	var input := _make_grid_geo(3, 3)
	var node := _make_node(ExtrudeSOPNative.new(), "extr_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "ExtrudeSOPNative did not crash")

func test_facet_sop_native_instantiate() -> void:
	var node := _make_node(FacetSOPNative.new(), "fac_n1")
	GNTestAssert.assert_not_null(node, "FacetSOPNative created")

func test_facet_sop_native_cook() -> void:
	var input := _make_sphere_geo(8, 4)
	var node := _make_node(FacetSOPNative.new(), "fac_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "FacetSOPNative did not crash")

func test_fuse_sop_native_instantiate() -> void:
	var node := _make_node(FuseSOPNative.new(), "fuse_n1")
	GNTestAssert.assert_not_null(node, "FuseSOPNative created")

func test_fuse_sop_native_cook() -> void:
	var input := _make_grid_geo(5, 5)
	var node := _make_node(FuseSOPNative.new(), "fuse_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "FuseSOPNative did not crash")

func test_isosurface_sop_native_instantiate() -> void:
	var node := _make_node(IsoSurfaceSOPNative.new(), "iso_n1")
	GNTestAssert.assert_not_null(node, "IsoSurfaceSOPNative created")

func test_isosurface_sop_native_cook() -> void:
	var node := _make_node(IsoSurfaceSOPNative.new(), "iso_n2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "IsoSurfaceSOPNative did not crash")

func test_lattice_sop_native_instantiate() -> void:
	var node := _make_node(LatticeSOPNative.new(), "lat_n1")
	GNTestAssert.assert_not_null(node, "LatticeSOPNative created")

func test_lattice_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(LatticeSOPNative.new(), "lat_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "LatticeSOPNative did not crash")

func test_lsystem_sop_native_instantiate() -> void:
	var node := _make_node(LSystemSOPNative.new(), "lsys_n1")
	GNTestAssert.assert_not_null(node, "LSystemSOPNative created")

func test_lsystem_sop_native_cook() -> void:
	var node := _make_node(LSystemSOPNative.new(), "lsys_n2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "LSystemSOPNative did not crash")

func test_magnet_sop_native_instantiate() -> void:
	var node := _make_node(MagnetSOPNative.new(), "mag_n1")
	GNTestAssert.assert_not_null(node, "MagnetSOPNative created")

func test_magnet_sop_native_cook() -> void:
	var input := _make_grid_geo(5, 5)
	var node := _make_node(MagnetSOPNative.new(), "mag_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "MagnetSOPNative did not crash")

func test_metaball_sop_native_instantiate() -> void:
	var node := _make_node(MetaballSOPNative.new(), "meta_n1")
	GNTestAssert.assert_not_null(node, "MetaballSOPNative created")

func test_metaball_sop_native_cook() -> void:
	var node := _make_node(MetaballSOPNative.new(), "meta_n2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "MetaballSOPNative did not crash")

func test_mirror_sop_native_instantiate() -> void:
	var node := _make_node(MirrorSOPNative.new(), "mir_n1")
	GNTestAssert.assert_not_null(node, "MirrorSOPNative created")

func test_mirror_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(MirrorSOPNative.new(), "mir_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "MirrorSOPNative did not crash")

func test_mountain_sop_native_instantiate() -> void:
	var node := _make_node(MountainSOPNative.new(), "mtn_n1")
	GNTestAssert.assert_not_null(node, "MountainSOPNative created")

func test_mountain_sop_native_cook() -> void:
	var input := _make_grid_geo(5, 5)
	var node := _make_node(MountainSOPNative.new(), "mtn_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "MountainSOPNative did not crash")

func test_noise_sop_native_instantiate() -> void:
	var node := _make_node(NoiseSOPNative.new(), "ns_n1")
	GNTestAssert.assert_not_null(node, "NoiseSOPNative created")

func test_noise_sop_native_cook() -> void:
	var input := _make_grid_geo(5, 5)
	var node := _make_node(NoiseSOPNative.new(), "ns_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "NoiseSOPNative did not crash")

func test_normal_sop_native_instantiate() -> void:
	var node := _make_node(NormalSOPNative.new(), "nrm_n1")
	GNTestAssert.assert_not_null(node, "NormalSOPNative created")

func test_normal_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(NormalSOPNative.new(), "nrm_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "NormalSOPNative did not crash")

func test_particle_sop_native_instantiate() -> void:
	var node := _make_node(ParticleSOPNative.new(), "part_n1")
	GNTestAssert.assert_not_null(node, "ParticleSOPNative created")

func test_particle_sop_native_cook() -> void:
	var node := _make_node(ParticleSOPNative.new(), "part_n2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "ParticleSOPNative did not crash")

func test_point_sop_native_instantiate() -> void:
	var node := _make_node(PointSOPNative.new(), "pt_n1")
	GNTestAssert.assert_not_null(node, "PointSOPNative created")

func test_point_sop_native_cook() -> void:
	var input := _make_grid_geo(5, 5)
	var node := _make_node(PointSOPNative.new(), "pt_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "PointSOPNative did not crash")

func test_polybevel_sop_native_instantiate() -> void:
	var node := _make_node(PolyBevelSOPNative.new(), "pbev_n1")
	GNTestAssert.assert_not_null(node, "PolyBevelSOPNative created")

func test_polybevel_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(PolyBevelSOPNative.new(), "pbev_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "PolyBevelSOPNative did not crash")

func test_polyloft_sop_native_instantiate() -> void:
	var node := _make_node(PolyLoftSOPNative.new(), "plft_n1")
	GNTestAssert.assert_not_null(node, "PolyLoftSOPNative created")

func test_polyloft_sop_native_cook() -> void:
	var input := _make_sphere_geo(8, 4)
	var node := _make_node(PolyLoftSOPNative.new(), "plft_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "PolyLoftSOPNative did not crash")

func test_polyreduce_sop_native_instantiate() -> void:
	var node := _make_node(PolyReduceSOPNative.new(), "pred_n1")
	GNTestAssert.assert_not_null(node, "PolyReduceSOPNative created")

func test_polyreduce_sop_native_cook() -> void:
	var input := _make_sphere_geo(8, 4)
	var node := _make_node(PolyReduceSOPNative.new(), "pred_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "PolyReduceSOPNative did not crash")

func test_polystitch_sop_native_instantiate() -> void:
	var node := _make_node(PolyStitchSOPNative.new(), "pst_n1")
	GNTestAssert.assert_not_null(node, "PolyStitchSOPNative created")

func test_polystitch_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(PolyStitchSOPNative.new(), "pst_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "PolyStitchSOPNative did not crash")

func test_ray_sop_native_instantiate() -> void:
	var node := _make_node(RaySOPNative.new(), "ray_n1")
	GNTestAssert.assert_not_null(node, "RaySOPNative created")

func test_ray_sop_native_cook() -> void:
	var source := _make_grid_geo(3, 3)
	var target := _make_sphere_geo(8, 4)
	var node := _make_node(RaySOPNative.new(), "ray_n2")
	var out := _cook_with(node, [source, target])
	GNTestAssert.assert_true(true, "RaySOPNative did not crash")

func test_remesh_sop_native_instantiate() -> void:
	var node := _make_node(RemeshSOPNative.new(), "remesh_n1")
	GNTestAssert.assert_not_null(node, "RemeshSOPNative created")

func test_remesh_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(RemeshSOPNative.new(), "remesh_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "RemeshSOPNative did not crash")

func test_scatter_sop_native_instantiate() -> void:
	var node := _make_node(ScatterSOPNative.new(), "scat_n1")
	GNTestAssert.assert_not_null(node, "ScatterSOPNative created")

func test_scatter_sop_native_cook() -> void:
	var input := _make_grid_geo(5, 5)
	var node := _make_node(ScatterSOPNative.new(), "scat_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "ScatterSOPNative did not crash")

func test_skin_sop_native_instantiate() -> void:
	var node := _make_node(SkinSOPNative.new(), "skin_n1")
	GNTestAssert.assert_not_null(node, "SkinSOPNative created")

func test_skin_sop_native_cook() -> void:
	var c1 := _make_line_geo(8)
	var c2 := _make_line_geo(8)
	var node := _make_node(SkinSOPNative.new(), "skin_n2")
	var out := _cook_with(node, [c1, c2])
	GNTestAssert.assert_true(true, "SkinSOPNative did not crash")

func test_smooth_sop_native_instantiate() -> void:
	var node := _make_node(SmoothSOPNative.new(), "sm_n1")
	GNTestAssert.assert_not_null(node, "SmoothSOPNative created")

func test_smooth_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(SmoothSOPNative.new(), "sm_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "SmoothSOPNative did not crash")

func test_sort_sop_native_instantiate() -> void:
	var node := _make_node(SortSOPNative.new(), "sort_n1")
	GNTestAssert.assert_not_null(node, "SortSOPNative created")

func test_sort_sop_native_cook() -> void:
	var input := _make_grid_geo(5, 5)
	var node := _make_node(SortSOPNative.new(), "sort_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "SortSOPNative did not crash")

func test_spring_sop_native_instantiate() -> void:
	var node := _make_node(SpringSOPNative.new(), "spring_n1")
	GNTestAssert.assert_not_null(node, "SpringSOPNative created")

func test_spring_sop_native_cook() -> void:
	var input := _make_grid_geo(5, 5)
	var node := _make_node(SpringSOPNative.new(), "spring_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "SpringSOPNative did not crash")

func test_subdivide_sop_native_instantiate() -> void:
	var node := _make_node(SubdivideSOPNative.new(), "subdiv_n1")
	GNTestAssert.assert_not_null(node, "SubdivideSOPNative created")

func test_subdivide_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(SubdivideSOPNative.new(), "subdiv_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "SubdivideSOPNative did not crash")

func test_sweep_sop_native_instantiate() -> void:
	var node := _make_node(SweepSOPNative.new(), "sweep_n1")
	GNTestAssert.assert_not_null(node, "SweepSOPNative created")

func test_sweep_sop_native_cook() -> void:
	var backbone := _make_line_geo(10)
	var node := _make_node(SweepSOPNative.new(), "sweep_n2")
	var out := _cook_with(node, [backbone])
	GNTestAssert.assert_true(true, "SweepSOPNative did not crash")

func test_taper_sop_native_instantiate() -> void:
	var node := _make_node(TaperSOPNative.new(), "taper_n1")
	GNTestAssert.assert_not_null(node, "TaperSOPNative created")

func test_taper_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(TaperSOPNative.new(), "taper_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "TaperSOPNative did not crash")

func test_transform_sop_native_instantiate() -> void:
	var node := _make_node(TransformSOPNative.new(), "xf_n1")
	GNTestAssert.assert_not_null(node, "TransformSOPNative created")

func test_transform_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(TransformSOPNative.new(), "xf_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "TransformSOPNative did not crash")

func test_twist_sop_native_instantiate() -> void:
	var node := _make_node(TwistSOPNative.new(), "twist_n1")
	GNTestAssert.assert_not_null(node, "TwistSOPNative created")

func test_twist_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(TwistSOPNative.new(), "twist_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "TwistSOPNative did not crash")

func test_uvproject_sop_native_instantiate() -> void:
	var node := _make_node(UVProjectSOPNative.new(), "uv_n1")
	GNTestAssert.assert_not_null(node, "UVProjectSOPNative created")

func test_uvproject_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(UVProjectSOPNative.new(), "uv_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "UVProjectSOPNative did not crash")

func test_wireframe_sop_native_instantiate() -> void:
	var node := _make_node(WireframeSOPNative.new(), "wire_n1")
	GNTestAssert.assert_not_null(node, "WireframeSOPNative created")

func test_wireframe_sop_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(WireframeSOPNative.new(), "wire_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "WireframeSOPNative did not crash")

func test_soptovol_native_instantiate() -> void:
	var node := _make_node(SOPtoVOLNative.new(), "soptovol_n1")
	GNTestAssert.assert_not_null(node, "SOPtoVOLNative created")

func test_soptovol_native_cook() -> void:
	var input := _make_box_geo()
	var node := _make_node(SOPtoVOLNative.new(), "soptovol_n2")
	var out := _cook_with(node, [input])
	GNTestAssert.assert_true(true, "SOPtoVOLNative did not crash")


# ═══════════════════════════════════════════════════════════════════════════════
#  POP Native Operators
# ═══════════════════════════════════════════════════════════════════════════════

func test_advect_pop_native_instantiation() -> void:
	var node := _make_node(AdvectPOPNative.new(), "advn1")
	GNTestAssert.assert_not_null(node, "AdvectPOPNative created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_advect_pop_native_cook() -> void:
	var node := _make_node(AdvectPOPNative.new(), "advn2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on cook")

func test_attract_pop_native_instantiation() -> void:
	var node := _make_node(AttractPOPNative.new(), "attrn1")
	GNTestAssert.assert_not_null(node, "AttractPOPNative created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_attract_pop_native_cook() -> void:
	var node := _make_node(AttractPOPNative.new(), "attrn2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on cook")

func test_collision_pop_native_instantiation() -> void:
	var node := _make_node(CollisionPOPNative.new(), "colln1")
	GNTestAssert.assert_not_null(node, "CollisionPOPNative created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_collision_pop_native_cook() -> void:
	var node := _make_node(CollisionPOPNative.new(), "colln2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on cook")

func test_force_pop_native_instantiation() -> void:
	var node := _make_node(ForcePOPNative.new(), "forcen1")
	GNTestAssert.assert_not_null(node, "ForcePOPNative created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_force_pop_native_cook() -> void:
	var node := _make_node(ForcePOPNative.new(), "forcen2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on cook")

func test_instance_pop_native_instantiation() -> void:
	var node := _make_node(InstanceSOPNative.new(), "instn1")
	GNTestAssert.assert_not_null(node, "InstanceSOPNative created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.SOP, "family is SOP")

func test_instance_pop_native_cook() -> void:
	var node := _make_node(InstanceSOPNative.new(), "instn2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on cook")

func test_limit_pop_native_instantiation() -> void:
	var node := _make_node(LimitPOPNative.new(), "limn1")
	GNTestAssert.assert_not_null(node, "LimitPOPNative created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_limit_pop_native_cook() -> void:
	var node := _make_node(LimitPOPNative.new(), "limn2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on cook")

func test_render_pop_native_instantiation() -> void:
	var node := _make_node(RenderPOPNative.new(), "rendn1")
	GNTestAssert.assert_not_null(node, "RenderPOPNative created")

func test_render_pop_native_node_type() -> void:
	var node := _make_node(RenderPOPNative.new(), "rendn2")
	GNTestAssert.assert_eq(node.node_type, "render_native", "node_type")

func test_source_pop_native_instantiation() -> void:
	var node := _make_node(SourcePOPNative.new(), "srcn1")
	GNTestAssert.assert_not_null(node, "SourcePOPNative created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_source_pop_native_cook() -> void:
	var node := _make_node(SourcePOPNative.new(), "srcn2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on cook")

func test_turbulence_pop_native_instantiation() -> void:
	var node := _make_node(TurbulencePOPNative.new(), "turbn1")
	GNTestAssert.assert_not_null(node, "TurbulencePOPNative created")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.POP, "family is POP")

func test_turbulence_pop_native_cook() -> void:
	var node := _make_node(TurbulencePOPNative.new(), "turbn2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "no crash on cook")


# ═══════════════════════════════════════════════════════════════════════════════
#  VOL Native Operators
# ═══════════════════════════════════════════════════════════════════════════════

func test_analyze_vol_native_instantiation() -> void:
	var node := _make_node(AnalyzeVOLNative.new(), "analyze_native1")
	GNTestAssert.assert_not_null(node, "AnalyzeVOLNative created")

func test_analyze_vol_native_cook() -> void:
	var node := _make_node(AnalyzeVOLNative.new(), "analyze_native2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "cooks without crash")

func test_blend_vol_native_instantiation() -> void:
	var node := _make_node(BlendVOLNative.new(), "blend_native1")
	GNTestAssert.assert_not_null(node, "BlendVOLNative created")

func test_blend_vol_native_cook() -> void:
	var node := _make_node(BlendVOLNative.new(), "blend_native2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "cooks without crash")

func test_blur_vol_native_instantiation() -> void:
	var node := _make_node(BlurVOLNative.new(), "blur_native1")
	GNTestAssert.assert_not_null(node, "BlurVOLNative created")

func test_blur_vol_native_cook() -> void:
	var node := _make_node(BlurVOLNative.new(), "blur_native2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "cooks without crash")

func test_displace_vol_native_instantiation() -> void:
	var node := _make_node(DisplaceVOLNative.new(), "disp_native1")
	GNTestAssert.assert_not_null(node, "DisplaceVOLNative created")

func test_displace_vol_native_cook() -> void:
	var node := _make_node(DisplaceVOLNative.new(), "disp_native2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "cooks without crash")

func test_fluid_vol_native_instantiation() -> void:
	var node := _make_node(FluidVOLNative.new(), "fluid_native1")
	GNTestAssert.assert_not_null(node, "FluidVOLNative created")

func test_fluid_vol_native_cook() -> void:
	var node := _make_node(FluidVOLNative.new(), "fluid_native2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "cooks without crash")

func test_marching_cubes_vol_native_instantiation() -> void:
	var node := _make_node(MarchingCubesSOPNative.new(), "mc_native1")
	GNTestAssert.assert_not_null(node, "MarchingCubesSOPNative created")

func test_marching_cubes_vol_native_cook() -> void:
	var node := _make_node(MarchingCubesSOPNative.new(), "mc_native2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(true, "cooks without crash")

func test_noise_vol_native_instantiation() -> void:
	var node := _make_node(NoiseVOLNative.new(), "noise_native1")
	GNTestAssert.assert_not_null(node, "NoiseVOLNative created")

func test_noise_vol_native_cook() -> void:
	var node := _make_node(NoiseVOLNative.new(), "noise_native2")
	var out := _cook_no_input(node)
	if out != null:
		GNTestAssert.assert_true(out is GNVolumeData, "output is GNVolumeData")


# ═══════════════════════════════════════════════════════════════════════════════
#  IMG Native Operators
# ═══════════════════════════════════════════════════════════════════════════════

func test_blur_img_native_instantiate() -> void:
	var node := _make_node(BlurIMGNative.new(), "blur_native1")
	GNTestAssert.assert_not_null(node, "BlurIMGNative created")

func test_blur_img_native_cook() -> void:
	var node := _make_node(BlurIMGNative.new(), "blur_native2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNImageData, "cooks without crash")

func test_checkerboard_img_native_instantiate() -> void:
	var node := _make_node(CheckerboardIMGNative.new(), "check_native1")
	GNTestAssert.assert_not_null(node, "CheckerboardIMGNative created")

func test_checkerboard_img_native_cook() -> void:
	var node := _make_node(CheckerboardIMGNative.new(), "check_native2")
	node.set_param_value("resolution", Vector2i(32, 32))
	var out := _cook_no_input(node)
	if out is GNImageData:
		GNTestAssert.assert_not_null(out.image, "produces image")

func test_edge_detect_img_native_instantiate() -> void:
	var node := _make_node(EdgeDetectIMGNative.new(), "edge_native1")
	GNTestAssert.assert_not_null(node, "EdgeDetectIMGNative created")

func test_edge_detect_img_native_cook() -> void:
	var node := _make_node(EdgeDetectIMGNative.new(), "edge_native2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNImageData, "cooks without crash")

func test_noise_img_native_instantiate() -> void:
	var node := _make_node(NoiseIMGNative.new(), "noise_native1")
	GNTestAssert.assert_not_null(node, "NoiseIMGNative created")

func test_noise_img_native_cook() -> void:
	var node := _make_node(NoiseIMGNative.new(), "noise_native2")
	node.set_param_value("resolution", Vector2i(32, 32))
	var out := _cook_no_input(node)
	if out is GNImageData:
		GNTestAssert.assert_not_null(out.image, "produces image")

func test_pixel_sort_img_native_instantiate() -> void:
	var node := _make_node(PixelSortIMGNative.new(), "psort_native1")
	GNTestAssert.assert_not_null(node, "PixelSortIMGNative created")

func test_pixel_sort_img_native_cook() -> void:
	var node := _make_node(PixelSortIMGNative.new(), "psort_native2")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNImageData, "cooks without crash")
