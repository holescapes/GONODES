extends Node
## Operator contract tests for the FIX family (gn_ext_pixel_mapper).
## Tests verify: instantiation, node_type, family, cook-null safety,
## fixture geometry correctness, data flow, parameter effects,
## edge cases, data type integrity, placement transforms, and multi-output.


func _make_node(node: GNNode, id: String) -> GNNode:
	node.initialize(id)
	return node


func _cook_no_input(node: GNNode) -> GNData:
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, 0)
	return node.cached_output


func _cook_with(node: GNNode, data: Array[GNData]) -> GNData:
	node.execute_cook(data, 0)
	return node.cached_output


## Creates a simple GNFixtureData for testing downstream operators.
func _make_fixture(p_name: String, p_count: int, p_layout: String = "rgb",
		p_universe: int = 1, p_start_channel: int = 1,
		p_shape: StringName = &"strip") -> GNFixtureData:
	var fd := GNFixtureData.new()
	fd.valid = true
	fd.fixture_name = p_name
	fd.led_count = p_count
	fd.channel_layout = p_layout
	fd.channels_per_led = GNFixtureData.channels_for_layout(p_layout)
	fd.universe = p_universe
	fd.start_channel = p_start_channel
	fd.shape = p_shape
	fd.led_positions.resize(p_count)
	for i in range(p_count):
		var t: float = float(i) / maxf(float(p_count - 1), 1.0)
		fd.led_positions[i] = Vector2(t, 0.5)
	return fd


# ============================================================================
# GNFixtureData -- data type tests
# ============================================================================

func test_fixture_data_channels_for_layout() -> void:
	GNTestAssert.assert_eq(GNFixtureData.channels_for_layout("rgb"),  3, "rgb=3")
	GNTestAssert.assert_eq(GNFixtureData.channels_for_layout("rgbw"), 4, "rgbw=4")
	GNTestAssert.assert_eq(GNFixtureData.channels_for_layout("r"),    1, "r=1")
	GNTestAssert.assert_eq(GNFixtureData.channels_for_layout("g"),    1, "g=1")
	GNTestAssert.assert_eq(GNFixtureData.channels_for_layout("b"),    1, "b=1")
	GNTestAssert.assert_eq(GNFixtureData.channels_for_layout("w"),    1, "w=1")
	GNTestAssert.assert_eq(GNFixtureData.channels_for_layout("unknown"), 3, "unknown defaults to 3")


func test_fixture_data_family() -> void:
	var fd := GNFixtureData.new()
	GNTestAssert.assert_eq(fd.get_family(), GNFamily.string_to_type("FIX"), "family is FIX")


func test_fixture_data_duplicate() -> void:
	var fd := GNFixtureData.new()
	fd.valid = true
	fd.fixture_name = "test"
	fd.led_count = 10
	fd.channel_layout = "rgbw"
	fd.channels_per_led = 4
	fd.universe = 2
	fd.start_channel = 100
	fd.shape = &"grid"
	fd.led_positions.resize(10)
	fd.led_positions[0] = Vector2(0.1, 0.2)
	fd.led_positions[9] = Vector2(0.9, 0.8)
	var copy: GNFixtureData = fd.duplicate_data() as GNFixtureData
	GNTestAssert.assert_not_null(copy, "duplicate_data returns non-null")
	GNTestAssert.assert_eq(copy.fixture_name, "test", "name copied")
	GNTestAssert.assert_eq(copy.led_count, 10, "led_count copied")
	GNTestAssert.assert_eq(copy.channel_layout, "rgbw", "channel_layout copied")
	GNTestAssert.assert_eq(copy.channels_per_led, 4, "channels_per_led copied")
	GNTestAssert.assert_eq(copy.universe, 2, "universe copied")
	GNTestAssert.assert_eq(copy.start_channel, 100, "start_channel copied")
	GNTestAssert.assert_eq(copy.shape, &"grid", "shape copied")
	GNTestAssert.assert_eq(copy.led_positions[0], Vector2(0.1, 0.2), "first pos copied")
	GNTestAssert.assert_eq(copy.led_positions[9], Vector2(0.9, 0.8), "last pos copied")
	# Verify deep copy
	copy.led_positions[0] = Vector2(0.99, 0.99)
	GNTestAssert.assert_eq(fd.led_positions[0], Vector2(0.1, 0.2), "deep copy independent")


func test_fixture_data_invalidate() -> void:
	var fd := _make_fixture("test", 10)
	GNTestAssert.assert_eq(fd.led_count, 10, "before invalidate")
	fd.invalidate()
	GNTestAssert.assert_eq(fd.led_count, 0, "led_count zeroed")
	GNTestAssert.assert_eq(fd.led_positions.size(), 0, "positions cleared")


func test_fixture_data_preview_text() -> void:
	var fd := _make_fixture("mystrip", 60, "rgb", 1, 1)
	GNTestAssert.assert_contains(fd.get_preview_text(), "mystrip", "preview has name")
	GNTestAssert.assert_contains(fd.get_preview_text(), "60", "preview has led_count")
	GNTestAssert.assert_contains(fd.get_preview_text(), "rgb", "preview has layout")
	var empty := GNFixtureData.new()
	GNTestAssert.assert_eq(empty.get_preview_text(), "empty", "empty fixture text")


func test_fixture_data_expression_values() -> void:
	var fd := _make_fixture("expr_test", 30, "rgbw", 2, 100)
	GNTestAssert.assert_eq(fd.get_expression_value("led_count"), 30.0, "expr led_count")
	GNTestAssert.assert_eq(fd.get_expression_value("universe"), 2.0, "expr universe")
	GNTestAssert.assert_eq(fd.get_expression_value("start_channel"), 100.0, "expr start_channel")
	GNTestAssert.assert_eq(fd.get_expression_value("channels_per_led"), 4.0, "expr channels_per_led")
	GNTestAssert.assert_eq(fd.get_expression_value("name"), "expr_test", "expr name")
	GNTestAssert.assert_eq(fd.get_expression_value("nonexistent"), 0.0, "expr unknown key")


func test_fixture_data_expression_info() -> void:
	var fd := _make_fixture("info_test", 20, "rgb", 1, 50)
	var info: Dictionary = fd.get_expression_info()
	GNTestAssert.assert_has_key(info, "led_count", "info has led_count")
	GNTestAssert.assert_has_key(info, "universe", "info has universe")
	GNTestAssert.assert_has_key(info, "start_channel", "info has start_channel")
	GNTestAssert.assert_has_key(info, "channels_per_led", "info has channels_per_led")
	GNTestAssert.assert_has_key(info, "name", "info has name")


func test_fixture_data_summary() -> void:
	var fd := _make_fixture("sum", 10, "rgb")
	GNTestAssert.assert_not_empty(fd.get_data_summary(), "non-empty summary")
	var empty := GNFixtureData.new()
	GNTestAssert.assert_empty(empty.get_data_summary(), "empty fixture summary")


func test_fixture_data_absolute_dmx() -> void:
	var fd := GNFixtureData.new()
	fd.universe = 1
	fd.start_channel = 1
	GNTestAssert.assert_eq(fd.get_absolute_dmx(), 0, "Uni 1 Ch 1 = absolute 0")
	fd.universe = 2
	fd.start_channel = 1
	GNTestAssert.assert_eq(fd.get_absolute_dmx(), 512, "Uni 2 Ch 1 = absolute 512")
	fd.universe = 1
	fd.start_channel = 100
	GNTestAssert.assert_eq(fd.get_absolute_dmx(), 99, "Uni 1 Ch 100 = absolute 99")


# ============================================================================
# GNFixtureBase -- base class tests
# ============================================================================

func test_fixture_base_family_resolution() -> void:
	GNTestAssert.assert_gt(GNFixtureBase.FIX_FAMILY, -1, "FIX_FAMILY resolved")
	GNTestAssert.assert_eq(GNFixtureBase.FIX_FAMILY,
		GNFamily.string_to_type("FIX"), "FIX_FAMILY matches registry")


func test_fixture_base_is_family_data() -> void:
	var node := _make_node(StripFIX.new(), "base1")
	var fd := GNFixtureData.new()
	GNTestAssert.assert_true(node._is_family_data(fd), "GNFixtureData passes family check")


func test_fixture_base_get_input_fix() -> void:
	var node := _make_node(NullFIX.new(), "null_base")
	var fd := _make_fixture("test", 5)
	var inputs: Array[GNData] = [fd]
	var result: GNFixtureData = node._get_input_fix(inputs, 0)
	GNTestAssert.assert_not_null(result, "_get_input_fix returns valid data")
	GNTestAssert.assert_eq(result.fixture_name, "test", "correct data returned")


func test_fixture_base_get_input_fix_wrong_type() -> void:
	var node := _make_node(NullFIX.new(), "null_base")
	var inputs: Array[GNData] = []
	var result: GNFixtureData = node._get_input_fix(inputs, 0)
	GNTestAssert.assert_null(result, "_get_input_fix returns null on empty")


func test_fixture_base_prepare_output() -> void:
	var node := _make_node(StripFIX.new(), "prep1")
	var out1: GNFixtureData = node._prepare_output()
	GNTestAssert.assert_not_null(out1, "first prepare non-null")
	GNTestAssert.assert_true(out1.valid, "output marked valid")
	var out2: GNFixtureData = node._prepare_output()
	GNTestAssert.assert_true(out1 == out2, "reuses cached instance")


# ============================================================================
# StripFIX -- linear LED strip (local space)
# ============================================================================

func test_strip_fix_instantiate() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	GNTestAssert.assert_not_null(node, "StripFIX instantiates")
	GNTestAssert.assert_eq(node.node_type, "strip_fix", "node_type")
	GNTestAssert.assert_eq(node.family, GNFixtureBase.FIX_FAMILY, "family is FIX")


func test_strip_fix_cook_defaults() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_not_null(out, "StripFIX produces output")
	GNTestAssert.assert_eq(out.led_count, 60, "default 60 LEDs")
	GNTestAssert.assert_eq(out.led_positions.size(), 60, "positions array size matches")
	GNTestAssert.assert_eq(out.channel_layout, "rgb", "default rgb layout")
	GNTestAssert.assert_eq(out.channels_per_led, 3, "rgb = 3 channels")
	GNTestAssert.assert_eq(out.fixture_name, "strip", "default name")
	GNTestAssert.assert_eq(out.universe, 0, "default universe (0-based)")
	GNTestAssert.assert_eq(out.start_channel, 1, "default start_channel")
	GNTestAssert.assert_eq(out.shape, &"strip", "shape is strip")


func test_strip_fix_local_positions() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	node.set_param_value("led_count", 5)
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	# Local space: x from 0 to 1, y = 0.5
	GNTestAssert.assert_approx(out.led_positions[0].x, 0.0, 0.001, "LED 0 at x=0")
	GNTestAssert.assert_approx(out.led_positions[0].y, 0.5, 0.001, "LED 0 at y=0.5")
	GNTestAssert.assert_approx(out.led_positions[2].x, 0.5, 0.001, "LED 2 at x=0.5")
	GNTestAssert.assert_approx(out.led_positions[4].x, 1.0, 0.001, "LED 4 at x=1.0")


func test_strip_fix_single_led() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	node.set_param_value("led_count", 1)
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_eq(out.led_count, 1, "single LED")
	GNTestAssert.assert_eq(out.led_positions[0], Vector2(0.5, 0.5), "single LED at midpoint")


func test_strip_fix_even_spacing() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	node.set_param_value("led_count", 5)
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_approx(out.led_positions[0].x, 0.0, 0.001, "LED 0 at 0.0")
	GNTestAssert.assert_approx(out.led_positions[1].x, 0.25, 0.001, "LED 1 at 0.25")
	GNTestAssert.assert_approx(out.led_positions[2].x, 0.5, 0.001, "LED 2 at 0.5")
	GNTestAssert.assert_approx(out.led_positions[3].x, 0.75, 0.001, "LED 3 at 0.75")
	GNTestAssert.assert_approx(out.led_positions[4].x, 1.0, 0.001, "LED 4 at 1.0")


func test_strip_fix_rgbw_layout() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	node.set_param_value("channel_layout", 1)  # RGBW
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_eq(out.channel_layout, "rgbw", "rgbw layout")
	GNTestAssert.assert_eq(out.channels_per_led, 4, "rgbw = 4 channels")


func test_strip_fix_single_channel_layouts() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	for idx in [2, 3, 4, 5]:
		node.set_param_value("channel_layout", idx)
		var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
		GNTestAssert.assert_eq(out.channels_per_led, 1, "single channel layout idx=%d" % idx)


func test_strip_fix_universe_and_channel() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	node.set_param_value("fixture_name", "front_bar")
	node.set_param_value("universe", 2)
	node.set_param_value("start_channel", 100)
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_eq(out.fixture_name, "front_bar", "custom name")
	GNTestAssert.assert_eq(out.universe, 2, "universe 2")
	GNTestAssert.assert_eq(out.start_channel, 100, "start_channel 100")


# ============================================================================
# GridFIX -- 2D LED grid (local space)
# ============================================================================

func test_grid_fix_instantiate() -> void:
	var node := _make_node(GridFIX.new(), "grid1")
	GNTestAssert.assert_not_null(node, "GridFIX instantiates")
	GNTestAssert.assert_eq(node.node_type, "grid_fix", "node_type")
	GNTestAssert.assert_eq(node.family, GNFixtureBase.FIX_FAMILY, "family is FIX")


func test_grid_fix_cook_geometry() -> void:
	var node := _make_node(GridFIX.new(), "grid1")
	node.set_param_value("cols", 4)
	node.set_param_value("rows", 4)
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_not_null(out, "GridFIX produces output")
	GNTestAssert.assert_eq(out.led_count, 16, "4x4 = 16 LEDs")
	GNTestAssert.assert_eq(out.shape, &"grid", "shape is grid")


func test_grid_fix_corners() -> void:
	var node := _make_node(GridFIX.new(), "grid1")
	node.set_param_value("cols", 3)
	node.set_param_value("rows", 3)
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	# Local unit square: TL=(0,0), TR=(1,0), BL=(0,1), BR=(1,1)
	GNTestAssert.assert_eq(out.led_positions[0], Vector2(0.0, 0.0), "top-left corner")
	GNTestAssert.assert_eq(out.led_positions[2], Vector2(1.0, 0.0), "top-right corner")
	GNTestAssert.assert_eq(out.led_positions[6], Vector2(0.0, 1.0), "bottom-left corner")
	GNTestAssert.assert_eq(out.led_positions[8], Vector2(1.0, 1.0), "bottom-right corner")


func test_grid_fix_single_row() -> void:
	var node := _make_node(GridFIX.new(), "grid1")
	node.set_param_value("cols", 5)
	node.set_param_value("rows", 1)
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_eq(out.led_count, 5, "5x1 = 5 LEDs")
	GNTestAssert.assert_approx(out.led_positions[0].y, 0.0, 0.001, "single row y=0")
	GNTestAssert.assert_approx(out.led_positions[4].x, 1.0, 0.001, "last col x=1.0")


func test_grid_fix_single_column() -> void:
	var node := _make_node(GridFIX.new(), "grid1")
	node.set_param_value("cols", 1)
	node.set_param_value("rows", 5)
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_eq(out.led_count, 5, "1x5 = 5 LEDs")
	GNTestAssert.assert_approx(out.led_positions[0].x, 0.0, 0.001, "single col x=0")
	GNTestAssert.assert_approx(out.led_positions[4].y, 1.0, 0.001, "last row y=1.0")


# ============================================================================
# MatrixFIX -- LED matrix with rotation/skew (local space)
# ============================================================================

func test_matrix_fix_instantiate() -> void:
	var node := _make_node(MatrixFIX.new(), "matrix1")
	GNTestAssert.assert_not_null(node, "MatrixFIX instantiates")
	GNTestAssert.assert_eq(node.node_type, "matrix_fix", "node_type")
	GNTestAssert.assert_eq(node.family, GNFixtureBase.FIX_FAMILY, "family is FIX")


func test_matrix_fix_no_rotation() -> void:
	var node := _make_node(MatrixFIX.new(), "matrix1")
	node.set_param_value("cols", 2)
	node.set_param_value("rows", 2)
	node.set_param_value("pitch", Vector2(0.5, 0.5))
	node.set_param_value("rotation_deg", 0.0)
	node.set_param_value("skew_x", 0.0)
	node.set_param_value("skew_y", 0.0)
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_eq(out.led_count, 4, "2x2 = 4 LEDs")
	GNTestAssert.assert_eq(out.shape, &"matrix", "shape is matrix")
	GNTestAssert.assert_eq(out.led_positions[0], Vector2(0.0, 0.0), "origin LED")
	GNTestAssert.assert_approx(out.led_positions[1].x, 0.5, 0.001, "col 1 x")
	GNTestAssert.assert_approx(out.led_positions[2].y, 0.5, 0.001, "row 1 y")


func test_matrix_fix_90_degree_rotation() -> void:
	var node := _make_node(MatrixFIX.new(), "matrix1")
	node.set_param_value("cols", 2)
	node.set_param_value("rows", 1)
	node.set_param_value("pitch", Vector2(0.1, 0.1))
	node.set_param_value("rotation_deg", 90.0)
	node.set_param_value("skew_x", 0.0)
	node.set_param_value("skew_y", 0.0)
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	# LED 0 at origin (0, 0). LED 1: local (0.1, 0) rotated 90 deg -> (0, 0.1)
	GNTestAssert.assert_eq(out.led_positions[0], Vector2(0.0, 0.0), "origin unchanged")
	GNTestAssert.assert_approx(out.led_positions[1].x, 0.0, 0.01, "rotated x near 0")
	GNTestAssert.assert_approx(out.led_positions[1].y, 0.1, 0.01, "rotated y = 0.1")


func test_matrix_fix_skew() -> void:
	var node := _make_node(MatrixFIX.new(), "matrix1")
	node.set_param_value("cols", 2)
	node.set_param_value("rows", 2)
	node.set_param_value("pitch", Vector2(0.5, 0.5))
	node.set_param_value("rotation_deg", 0.0)
	node.set_param_value("skew_x", 0.1)
	node.set_param_value("skew_y", 0.0)
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	# Row 1, col 0: lx = 0*0.5 + 1*0.1 = 0.1, ly = 1*0.5 + 0*0 = 0.5
	GNTestAssert.assert_approx(out.led_positions[2].x, 0.1, 0.001, "skewed row 1 col 0 x")
	GNTestAssert.assert_approx(out.led_positions[2].y, 0.5, 0.001, "skewed row 1 col 0 y")


# ============================================================================
# CustomFIX -- LED positions from DAT
# ============================================================================

func test_custom_fix_instantiate() -> void:
	var node := _make_node(CustomFIX.new(), "custom1")
	GNTestAssert.assert_not_null(node, "CustomFIX instantiates")
	GNTestAssert.assert_eq(node.node_type, "custom_fix", "node_type")


func test_custom_fix_cook_null() -> void:
	var node := _make_node(CustomFIX.new(), "custom1")
	_cook_no_input(node)
	GNTestAssert.assert_not_empty(node.node_warning, "warning set on null input")


func test_custom_fix_cook_with_dat() -> void:
	var node := _make_node(CustomFIX.new(), "custom1")
	var dat := GNTableData.new()
	dat.valid = true
	dat.has_header = true
	dat.table = [
		PackedStringArray(["x", "y"]),
		PackedStringArray(["0.1", "0.2"]),
		PackedStringArray(["0.3", "0.4"]),
		PackedStringArray(["0.5", "0.6"]),
	]
	var out: GNFixtureData = _cook_with(node, [dat]) as GNFixtureData
	GNTestAssert.assert_not_null(out, "CustomFIX produces output from DAT")
	GNTestAssert.assert_eq(out.led_count, 3, "3 rows = 3 LEDs")
	GNTestAssert.assert_eq(out.shape, &"custom", "shape is custom")
	GNTestAssert.assert_approx(out.led_positions[0].x, 0.1, 0.001, "LED 0 x")
	GNTestAssert.assert_approx(out.led_positions[0].y, 0.2, 0.001, "LED 0 y")
	GNTestAssert.assert_approx(out.led_positions[2].x, 0.5, 0.001, "LED 2 x")


func test_custom_fix_missing_columns() -> void:
	var node := _make_node(CustomFIX.new(), "custom1")
	var dat := GNTableData.new()
	dat.valid = true
	dat.has_header = true
	dat.table = [
		PackedStringArray(["foo", "bar"]),
		PackedStringArray(["0.1", "0.2"]),
	]
	_cook_with(node, [dat])
	GNTestAssert.assert_not_empty(node.node_warning, "warning on missing x/y columns")


# ============================================================================
# NullFIX -- pass-through
# ============================================================================

func test_null_fix_instantiate() -> void:
	var node := _make_node(NullFIX.new(), "null1")
	GNTestAssert.assert_not_null(node, "NullFIX instantiates")
	GNTestAssert.assert_eq(node.node_type, "null_fix", "node_type")


func test_null_fix_cook_null() -> void:
	var node := _make_node(NullFIX.new(), "null1")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "NullFIX cook-null no crash")


func test_null_fix_pass_through() -> void:
	var node := _make_node(NullFIX.new(), "null1")
	var fd := _make_fixture("passthru", 20)
	var out: GNData = _cook_with(node, [fd])
	GNTestAssert.assert_not_null(out, "NullFIX passes data through")
	GNTestAssert.assert_true(out is GNFixtureData, "output is GNFixtureData")
	var fix_out: GNFixtureData = out as GNFixtureData
	GNTestAssert.assert_eq(fix_out.fixture_name, "passthru", "name preserved")
	GNTestAssert.assert_eq(fix_out.led_count, 20, "led_count preserved")


# ============================================================================
# SwitchFIX -- input selector
# ============================================================================

func test_switch_fix_instantiate() -> void:
	var node := _make_node(SwitchFIX.new(), "switch1")
	GNTestAssert.assert_not_null(node, "SwitchFIX instantiates")
	GNTestAssert.assert_eq(node.node_type, "switch_fix", "node_type")


func test_switch_fix_cook_null() -> void:
	var node := _make_node(SwitchFIX.new(), "switch1")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "SwitchFIX cook-null no crash")


func test_switch_fix_selects_by_index() -> void:
	var node := _make_node(SwitchFIX.new(), "switch1")
	node.update_dynamic_inputs(PackedInt32Array([0, 1]))
	var fd0 := _make_fixture("first", 10)
	var fd1 := _make_fixture("second", 20)
	node.set_param_value("index", 0)
	node.execute_cook([fd0, fd1], 1)
	var out0: GNFixtureData = node.cached_output as GNFixtureData
	GNTestAssert.assert_not_null(out0, "switch output non-null")
	GNTestAssert.assert_eq(out0.fixture_name, "first", "index 0 selects first")
	node.set_param_value("index", 1)
	node.execute_cook([fd0, fd1], 2)
	var out1: GNFixtureData = node.cached_output as GNFixtureData
	GNTestAssert.assert_not_null(out1, "switch output non-null at idx 1")
	GNTestAssert.assert_eq(out1.fixture_name, "second", "index 1 selects second")


# ============================================================================
# SelectFIX -- wireless reference
# ============================================================================

func test_select_fix_instantiate() -> void:
	var node := _make_node(SelectFIX.new(), "sel1")
	GNTestAssert.assert_not_null(node, "SelectFIX instantiates")
	GNTestAssert.assert_eq(node.node_type, "select_fix", "node_type")


func test_select_fix_cook_null() -> void:
	var node := _make_node(SelectFIX.new(), "sel1")
	_cook_no_input(node)
	GNTestAssert.assert_not_empty(node.node_warning, "warning when no source set")


# ============================================================================
# FileInFIX -- JSON file loader
# ============================================================================

func test_file_in_fix_instantiate() -> void:
	var node := _make_node(FileInFIX.new(), "filein1")
	GNTestAssert.assert_not_null(node, "FileInFIX instantiates")
	GNTestAssert.assert_eq(node.node_type, "file_in_fix", "node_type")


func test_file_in_fix_cook_null() -> void:
	var node := _make_node(FileInFIX.new(), "filein1")
	_cook_no_input(node)
	GNTestAssert.assert_not_empty(node.node_warning, "warning when no file path")


# ============================================================================
# FixtureSamplerTOP -- placement + multi-output
# ============================================================================

func test_fixture_sampler_instantiate() -> void:
	var node := _make_node(FixtureSamplerTOP.new(), "sampler1")
	GNTestAssert.assert_not_null(node, "FixtureSamplerTOP instantiates")
	GNTestAssert.assert_eq(node.node_type, "fixture_sampler", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family is TOP")


func test_fixture_sampler_cook_null() -> void:
	var node := _make_node(FixtureSamplerTOP.new(), "sampler1")
	_cook_no_input(node)
	GNTestAssert.assert_not_empty(node.node_warning, "warning when no source")


func test_fixture_sampler_cook_no_fixtures() -> void:
	var node := _make_node(FixtureSamplerTOP.new(), "sampler1")
	var tex := GNTextureData.new()
	tex.valid = true
	tex.texture = ImageTexture.create_from_image(
		Image.create(64, 64, false, Image.FORMAT_RGBA8))
	tex.resolution = Vector2i(64, 64)
	_cook_with(node, [tex])
	GNTestAssert.assert_not_empty(node.node_warning, "warning when no fixtures")


func test_fixture_sampler_port_structure() -> void:
	var node := _make_node(FixtureSamplerTOP.new(), "sampler1")
	GNTestAssert.assert_gt(node.input_ports.size(), 0, "has input ports")
	GNTestAssert.assert_eq(node.input_ports[0].family, GNFamily.Type.TOP, "input port 0 is TOP")
	if node.input_ports.size() > 1:
		GNTestAssert.assert_eq(node.input_ports[1].family,
			GNFamily.string_to_type("FIX"), "input port 1 is FIX")
	# Output: port 0 = TOP passthrough, port 1 = CHOP
	GNTestAssert.assert_eq(node.output_ports.size(), 2, "has 2 output ports")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.TOP, "output port 0 is TOP")
	GNTestAssert.assert_eq(node.output_ports[1].family, GNFamily.Type.CHOP, "output port 1 is CHOP")


func test_fixture_sampler_rebuild_manifest() -> void:
	var node := _make_node(FixtureSamplerTOP.new(), "sampler1")
	var fd0 := _make_fixture("strip_a", 10, "rgb", 1, 1, &"strip")
	var fd1 := _make_fixture("strip_b", 20, "rgbw", 2, 100, &"strip")
	var fix_inputs: Array[GNFixtureData] = [fd0, fd1]
	var pos0: PackedVector2Array = PackedVector2Array()
	pos0.resize(10)
	for i in range(10): pos0[i] = Vector2(float(i) / 9.0, 0.5)
	var pos1: PackedVector2Array = PackedVector2Array()
	pos1.resize(20)
	for i in range(20): pos1[i] = Vector2(float(i) / 19.0, 0.5)
	node._rebuild_led_pos_texture(fix_inputs, [pos0, pos1], [1, 2])
	GNTestAssert.assert_eq(node._total_leds, 30, "total LEDs = 10 + 20")
	GNTestAssert.assert_eq(node._max_channels, 4, "max channels = rgbw = 4")
	GNTestAssert.assert_size(node._fixture_manifest, 2, "2 fixture entries")
	GNTestAssert.assert_eq(node._fixture_manifest[0]["offset"], 0, "first fixture offset 0")
	GNTestAssert.assert_eq(node._fixture_manifest[1]["offset"], 10, "second fixture offset 10")
	GNTestAssert.assert_eq(node._fixture_manifest[0]["channel_layout"], "rgb", "manifest has layout")
	GNTestAssert.assert_eq(node._fixture_manifest[1]["universe"], 2, "manifest has universe")


func test_fixture_sampler_led_pos_texture() -> void:
	var node := _make_node(FixtureSamplerTOP.new(), "sampler1")
	node.set_param_value("sample_extent", Vector2(0.02, 0.03))
	var fd := _make_fixture("test", 5)
	var final_pos := PackedVector2Array()
	final_pos.resize(5)
	for i in range(5):
		final_pos[i] = Vector2(float(i) / 4.0, 0.5)
	var fix_inputs: Array[GNFixtureData] = [fd]
	node._rebuild_led_pos_texture(fix_inputs, [final_pos], [1])
	GNTestAssert.assert_not_null(node._led_pos_image, "LED pos image created")
	GNTestAssert.assert_eq(node._led_pos_image.get_width(), 5, "image width = total_leds")
	GNTestAssert.assert_eq(node._led_pos_image.get_height(), 1, "image height = 1")
	var px: Color = node._led_pos_image.get_pixel(0, 0)
	GNTestAssert.assert_approx(px.r, 0.0, 0.001, "pixel r = uv_x")
	GNTestAssert.assert_approx(px.g, 0.5, 0.001, "pixel g = uv_y")
	GNTestAssert.assert_approx(px.b, 0.02, 0.001, "pixel b = extent_x")
	GNTestAssert.assert_approx(px.a, 0.03, 0.001, "pixel a = extent_y")


# ============================================================================
# Placement transforms -- _apply_placement
# ============================================================================

func test_placement_strip() -> void:
	var fd := _make_fixture("test", 5, "rgb", 1, 1, &"strip")
	# fd has local positions: x from 0 to 1, y = 0.5
	var placement := { "a": Vector2(0.2, 0.3), "b": Vector2(0.8, 0.7) }
	var result: PackedVector2Array = FixtureSamplerTOP._apply_placement(fd, placement)
	GNTestAssert.assert_eq(result.size(), 5, "5 LEDs mapped")
	# LED 0: local x=0 -> lerp(a, b, 0) = a
	GNTestAssert.assert_approx(result[0].x, 0.2, 0.001, "LED 0 at a.x")
	GNTestAssert.assert_approx(result[0].y, 0.3, 0.001, "LED 0 at a.y")
	# LED 4: local x=1 -> lerp(a, b, 1) = b
	GNTestAssert.assert_approx(result[4].x, 0.8, 0.001, "LED 4 at b.x")
	GNTestAssert.assert_approx(result[4].y, 0.7, 0.001, "LED 4 at b.y")
	# LED 2: local x=0.5 -> midpoint
	GNTestAssert.assert_approx(result[2].x, 0.5, 0.001, "LED 2 at mid x")
	GNTestAssert.assert_approx(result[2].y, 0.5, 0.001, "LED 2 at mid y")


func test_placement_grid() -> void:
	var fd := GNFixtureData.new()
	fd.valid = true
	fd.fixture_name = "grid"
	fd.led_count = 4
	fd.shape = &"grid"
	fd.channel_layout = "rgb"
	fd.channels_per_led = 3
	fd.led_positions = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0),  # row 0
		Vector2(0, 1), Vector2(1, 1),  # row 1
	])
	var placement := {
		"tl": Vector2(0.1, 0.1), "tr": Vector2(0.9, 0.1),
		"bl": Vector2(0.1, 0.9), "br": Vector2(0.9, 0.9),
	}
	var result: PackedVector2Array = FixtureSamplerTOP._apply_placement(fd, placement)
	GNTestAssert.assert_eq(result.size(), 4, "4 LEDs mapped")
	GNTestAssert.assert_approx(result[0].x, 0.1, 0.001, "TL.x")
	GNTestAssert.assert_approx(result[0].y, 0.1, 0.001, "TL.y")
	GNTestAssert.assert_approx(result[1].x, 0.9, 0.001, "TR.x")
	GNTestAssert.assert_approx(result[1].y, 0.1, 0.001, "TR.y")
	GNTestAssert.assert_approx(result[2].x, 0.1, 0.001, "BL.x")
	GNTestAssert.assert_approx(result[2].y, 0.9, 0.001, "BL.y")
	GNTestAssert.assert_approx(result[3].x, 0.9, 0.001, "BR.x")
	GNTestAssert.assert_approx(result[3].y, 0.9, 0.001, "BR.y")


func test_placement_custom() -> void:
	var fd := GNFixtureData.new()
	fd.valid = true
	fd.fixture_name = "custom"
	fd.led_count = 2
	fd.shape = &"custom"
	fd.channel_layout = "rgb"
	fd.channels_per_led = 3
	fd.led_positions = PackedVector2Array([Vector2(0, 0), Vector2(0.5, 0.5)])
	var placement := { "offset": Vector2(0.2, 0.2), "scale": Vector2(0.6, 0.6) }
	var result: PackedVector2Array = FixtureSamplerTOP._apply_placement(fd, placement)
	GNTestAssert.assert_eq(result.size(), 2, "2 LEDs mapped")
	# LED 0: offset + (0,0)*scale = (0.2, 0.2)
	GNTestAssert.assert_approx(result[0].x, 0.2, 0.001, "LED 0 x")
	GNTestAssert.assert_approx(result[0].y, 0.2, 0.001, "LED 0 y")
	# LED 1: offset + (0.5,0.5)*0.6 = (0.2+0.3, 0.2+0.3) = (0.5, 0.5)
	GNTestAssert.assert_approx(result[1].x, 0.5, 0.001, "LED 1 x")
	GNTestAssert.assert_approx(result[1].y, 0.5, 0.001, "LED 1 y")


func test_placement_default_strip() -> void:
	var p: Dictionary = FixtureSamplerTOP._default_placement(&"strip")
	GNTestAssert.assert_has_key(p, "a", "strip has 'a'")
	GNTestAssert.assert_has_key(p, "b", "strip has 'b'")


func test_placement_default_grid() -> void:
	var p: Dictionary = FixtureSamplerTOP._default_placement(&"grid")
	GNTestAssert.assert_has_key(p, "tl", "grid has 'tl'")
	GNTestAssert.assert_has_key(p, "br", "grid has 'br'")


func test_placement_default_custom() -> void:
	var p: Dictionary = FixtureSamplerTOP._default_placement(&"custom")
	GNTestAssert.assert_has_key(p, "offset", "custom has 'offset'")
	GNTestAssert.assert_has_key(p, "scale", "custom has 'scale'")


# ============================================================================
# Serialization -- placement round-trip
# ============================================================================

func test_placement_serialization_round_trip() -> void:
	var node := _make_node(FixtureSamplerTOP.new(), "sampler1")
	node._placements = {
		1: { "a": Vector2(0.1, 0.2), "b": Vector2(0.8, 0.9) },
		2: { "tl": Vector2(0.0, 0.0), "tr": Vector2(1.0, 0.0),
			"bl": Vector2(0.0, 1.0), "br": Vector2(1.0, 1.0) },
	}
	var d: Dictionary = node.to_dict()
	GNTestAssert.assert_has_key(d, "fixture_placements", "serialized has placements")
	# Deserialize
	var node2 := _make_node(FixtureSamplerTOP.new(), "sampler2")
	node2.from_dict(d)
	GNTestAssert.assert_has_key(node2._placements, 1, "port 1 restored")
	GNTestAssert.assert_has_key(node2._placements, 2, "port 2 restored")
	var p1: Dictionary = node2._placements[1]
	GNTestAssert.assert_approx(p1["a"].x, 0.1, 0.001, "a.x round-tripped")
	GNTestAssert.assert_approx(p1["b"].y, 0.9, 0.001, "b.y round-tripped")


# ============================================================================
# Cross-operator data flow
# ============================================================================

func test_strip_into_null_fix() -> void:
	var strip := _make_node(StripFIX.new(), "strip1")
	strip.set_param_value("led_count", 5)
	var strip_out: GNFixtureData = _cook_no_input(strip) as GNFixtureData
	var null_fix := _make_node(NullFIX.new(), "null1")
	var through: GNFixtureData = _cook_with(null_fix, [strip_out]) as GNFixtureData
	GNTestAssert.assert_not_null(through, "data flows through NullFIX")
	GNTestAssert.assert_eq(through.led_count, 5, "led_count preserved through null")


func test_recook_reuses_cached_data() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	var out1: GNFixtureData = _cook_no_input(node) as GNFixtureData
	var out2: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_true(out1 == out2, "recook reuses same GNFixtureData instance")


# ============================================================================
# FixtureOverlay -- hit testing
# ============================================================================

func test_overlay_hit_test() -> void:
	var overlay := FixtureOverlay.new()
	overlay.fixtures = [{
		"shape": &"strip",
		"name": "test",
		"handles": PackedVector2Array([Vector2(0.2, 0.5), Vector2(0.8, 0.5)]),
		"leds": PackedVector2Array(),
		"color_index": 0,
	}]
	# Hit near handle 0
	var hit: Vector2i = overlay.hit_test_uv(Vector2(0.21, 0.51), 0.05)
	GNTestAssert.assert_eq(hit.x, 0, "hit fixture 0")
	GNTestAssert.assert_eq(hit.y, 0, "hit handle 0")
	# Hit near handle 1
	hit = overlay.hit_test_uv(Vector2(0.79, 0.49), 0.05)
	GNTestAssert.assert_eq(hit.x, 0, "hit fixture 0")
	GNTestAssert.assert_eq(hit.y, 1, "hit handle 1")
	# Miss
	hit = overlay.hit_test_uv(Vector2(0.5, 0.5), 0.05)
	GNTestAssert.assert_eq(hit.x, -1, "miss returns -1")
