extends Node
## Operator contract tests for the FIX family (gn_ext_pixel_mapper).
## Tests verify: instantiation, node_type, family, cook-null safety,
## fixture geometry correctness, data flow, parameter effects,
## edge cases, and data type integrity.


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
		p_dmx: int = 1) -> GNFixtureData:
	var fd := GNFixtureData.new()
	fd.valid = true
	fd.fixture_name = p_name
	fd.led_count = p_count
	fd.channel_layout = p_layout
	fd.channels_per_led = GNFixtureData.channels_for_layout(p_layout)
	fd.dmx_start = p_dmx
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
	fd.dmx_start = 512
	fd.sample_extent = Vector2(0.01, 0.02)
	fd.led_positions.resize(10)
	fd.led_positions[0] = Vector2(0.1, 0.2)
	fd.led_positions[9] = Vector2(0.9, 0.8)
	var copy: GNFixtureData = fd.duplicate_data() as GNFixtureData
	GNTestAssert.assert_not_null(copy, "duplicate_data returns non-null")
	GNTestAssert.assert_eq(copy.fixture_name, "test", "name copied")
	GNTestAssert.assert_eq(copy.led_count, 10, "led_count copied")
	GNTestAssert.assert_eq(copy.channel_layout, "rgbw", "channel_layout copied")
	GNTestAssert.assert_eq(copy.channels_per_led, 4, "channels_per_led copied")
	GNTestAssert.assert_eq(copy.dmx_start, 512, "dmx_start copied")
	GNTestAssert.assert_eq(copy.sample_extent, Vector2(0.01, 0.02), "sample_extent copied")
	GNTestAssert.assert_eq(copy.led_positions[0], Vector2(0.1, 0.2), "first pos copied")
	GNTestAssert.assert_eq(copy.led_positions[9], Vector2(0.9, 0.8), "last pos copied")
	# Verify deep copy -- modifying copy doesn't affect original
	copy.led_positions[0] = Vector2(0.99, 0.99)
	GNTestAssert.assert_eq(fd.led_positions[0], Vector2(0.1, 0.2), "deep copy independent")


func test_fixture_data_invalidate() -> void:
	var fd := _make_fixture("test", 10)
	GNTestAssert.assert_eq(fd.led_count, 10, "before invalidate")
	fd.invalidate()
	GNTestAssert.assert_eq(fd.led_count, 0, "led_count zeroed")
	GNTestAssert.assert_eq(fd.led_positions.size(), 0, "positions cleared")


func test_fixture_data_preview_text() -> void:
	var fd := _make_fixture("mystrip", 60, "rgb")
	GNTestAssert.assert_contains(fd.get_preview_text(), "mystrip", "preview has name")
	GNTestAssert.assert_contains(fd.get_preview_text(), "60", "preview has led_count")
	GNTestAssert.assert_contains(fd.get_preview_text(), "rgb", "preview has layout")
	var empty := GNFixtureData.new()
	GNTestAssert.assert_eq(empty.get_preview_text(), "empty", "empty fixture text")


func test_fixture_data_expression_values() -> void:
	var fd := _make_fixture("expr_test", 30, "rgbw", 100)
	GNTestAssert.assert_eq(fd.get_expression_value("led_count"), 30.0, "expr led_count")
	GNTestAssert.assert_eq(fd.get_expression_value("dmx_start"), 100.0, "expr dmx_start")
	GNTestAssert.assert_eq(fd.get_expression_value("channels_per_led"), 4.0, "expr channels_per_led")
	GNTestAssert.assert_eq(fd.get_expression_value("name"), "expr_test", "expr name")
	GNTestAssert.assert_eq(fd.get_expression_value("nonexistent"), 0.0, "expr unknown key")


func test_fixture_data_expression_info() -> void:
	var fd := _make_fixture("info_test", 20, "rgb", 50)
	var info: Dictionary = fd.get_expression_info()
	GNTestAssert.assert_has_key(info, "led_count", "info has led_count")
	GNTestAssert.assert_has_key(info, "dmx_start", "info has dmx_start")
	GNTestAssert.assert_has_key(info, "channels_per_led", "info has channels_per_led")
	GNTestAssert.assert_has_key(info, "name", "info has name")


func test_fixture_data_summary() -> void:
	var fd := _make_fixture("sum", 10, "rgb")
	GNTestAssert.assert_not_empty(fd.get_data_summary(), "non-empty summary")
	var empty := GNFixtureData.new()
	GNTestAssert.assert_empty(empty.get_data_summary(), "empty fixture summary")


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
# StripFIX -- linear LED strip
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
	GNTestAssert.assert_eq(out.dmx_start, 1, "default dmx_start")


func test_strip_fix_endpoints() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	node.set_param_value("led_count", 10)
	node.set_param_value("uv_start", Vector2(0.0, 0.5))
	node.set_param_value("uv_end", Vector2(1.0, 0.5))
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_not_null(out, "StripFIX produces output")
	GNTestAssert.assert_eq(out.led_positions[0], Vector2(0.0, 0.5), "first LED at uv_start")
	GNTestAssert.assert_eq(out.led_positions[9], Vector2(1.0, 0.5), "last LED at uv_end")


func test_strip_fix_single_led() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	node.set_param_value("led_count", 1)
	node.set_param_value("uv_start", Vector2(0.2, 0.3))
	node.set_param_value("uv_end", Vector2(0.8, 0.7))
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_eq(out.led_count, 1, "single LED")
	GNTestAssert.assert_eq(out.led_positions[0], Vector2(0.5, 0.5), "single LED at midpoint")


func test_strip_fix_even_spacing() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	node.set_param_value("led_count", 5)
	node.set_param_value("uv_start", Vector2(0.0, 0.0))
	node.set_param_value("uv_end", Vector2(1.0, 0.0))
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
	# R=2, G=3, B=4, W=5
	for idx in [2, 3, 4, 5]:
		node.set_param_value("channel_layout", idx)
		var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
		GNTestAssert.assert_eq(out.channels_per_led, 1, "single channel layout idx=%d" % idx)


func test_strip_fix_sample_extent() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	node.set_param_value("sample_extent", Vector2(0.05, 0.03))
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_eq(out.sample_extent, Vector2(0.05, 0.03), "sample_extent set")


func test_strip_fix_custom_name_and_dmx() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	node.set_param_value("fixture_name", "front_bar")
	node.set_param_value("dmx_start", 513)
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_eq(out.fixture_name, "front_bar", "custom name")
	GNTestAssert.assert_eq(out.dmx_start, 513, "custom dmx_start")


# ============================================================================
# GridFIX -- 2D LED grid
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
	GNTestAssert.assert_eq(out.led_positions.size(), 16, "positions array size")


func test_grid_fix_corners() -> void:
	var node := _make_node(GridFIX.new(), "grid1")
	node.set_param_value("cols", 3)
	node.set_param_value("rows", 3)
	node.set_param_value("uv_min", Vector2(0.0, 0.0))
	node.set_param_value("uv_max", Vector2(1.0, 1.0))
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	# Row-major: [0]=top-left, [2]=top-right, [6]=bottom-left, [8]=bottom-right
	GNTestAssert.assert_eq(out.led_positions[0], Vector2(0.0, 0.0), "top-left corner")
	GNTestAssert.assert_eq(out.led_positions[2], Vector2(1.0, 0.0), "top-right corner")
	GNTestAssert.assert_eq(out.led_positions[6], Vector2(0.0, 1.0), "bottom-left corner")
	GNTestAssert.assert_eq(out.led_positions[8], Vector2(1.0, 1.0), "bottom-right corner")


func test_grid_fix_single_row() -> void:
	var node := _make_node(GridFIX.new(), "grid1")
	node.set_param_value("cols", 5)
	node.set_param_value("rows", 1)
	node.set_param_value("uv_min", Vector2(0.0, 0.5))
	node.set_param_value("uv_max", Vector2(1.0, 0.5))
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_eq(out.led_count, 5, "5x1 = 5 LEDs")
	GNTestAssert.assert_approx(out.led_positions[0].y, 0.5, 0.001, "single row y=0.5")
	GNTestAssert.assert_approx(out.led_positions[4].y, 0.5, 0.001, "last col y=0.5")


func test_grid_fix_single_column() -> void:
	var node := _make_node(GridFIX.new(), "grid1")
	node.set_param_value("cols", 1)
	node.set_param_value("rows", 5)
	node.set_param_value("uv_min", Vector2(0.5, 0.0))
	node.set_param_value("uv_max", Vector2(0.5, 1.0))
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_eq(out.led_count, 5, "1x5 = 5 LEDs")
	GNTestAssert.assert_approx(out.led_positions[0].x, 0.5, 0.001, "single col x=0.5")
	GNTestAssert.assert_approx(out.led_positions[4].x, 0.5, 0.001, "last row x=0.5")


# ============================================================================
# MatrixFIX -- LED matrix with rotation/skew
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
	node.set_param_value("uv_origin", Vector2(0.0, 0.0))
	node.set_param_value("uv_pitch", Vector2(0.5, 0.5))
	node.set_param_value("rotation_deg", 0.0)
	node.set_param_value("skew_x", 0.0)
	node.set_param_value("skew_y", 0.0)
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_eq(out.led_count, 4, "2x2 = 4 LEDs")
	GNTestAssert.assert_eq(out.led_positions[0], Vector2(0.0, 0.0), "origin LED")
	GNTestAssert.assert_approx(out.led_positions[1].x, 0.5, 0.001, "col 1 x")
	GNTestAssert.assert_approx(out.led_positions[2].y, 0.5, 0.001, "row 1 y")


func test_matrix_fix_90_degree_rotation() -> void:
	var node := _make_node(MatrixFIX.new(), "matrix1")
	node.set_param_value("cols", 2)
	node.set_param_value("rows", 1)
	node.set_param_value("uv_origin", Vector2(0.5, 0.5))
	node.set_param_value("uv_pitch", Vector2(0.1, 0.1))
	node.set_param_value("rotation_deg", 90.0)
	node.set_param_value("skew_x", 0.0)
	node.set_param_value("skew_y", 0.0)
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	# LED 0 at origin (0.5, 0.5). LED 1: local (0.1, 0) rotated 90 deg -> (0, 0.1)
	GNTestAssert.assert_eq(out.led_positions[0], Vector2(0.5, 0.5), "origin unchanged")
	GNTestAssert.assert_approx(out.led_positions[1].x, 0.5, 0.01, "rotated x near origin")
	GNTestAssert.assert_approx(out.led_positions[1].y, 0.6, 0.01, "rotated y offset")


func test_matrix_fix_skew() -> void:
	var node := _make_node(MatrixFIX.new(), "matrix1")
	node.set_param_value("cols", 2)
	node.set_param_value("rows", 2)
	node.set_param_value("uv_origin", Vector2(0.0, 0.0))
	node.set_param_value("uv_pitch", Vector2(0.5, 0.5))
	node.set_param_value("rotation_deg", 0.0)
	node.set_param_value("skew_x", 0.1)
	node.set_param_value("skew_y", 0.0)
	var out: GNFixtureData = _cook_no_input(node) as GNFixtureData
	# Row 1, col 0: lx = 0 * 0.5 + 1 * 0.1 = 0.1, ly = 1 * 0.5 + 0 * 0 = 0.5
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
	# table row 0 = headers, rows 1-3 = data
	dat.table = [
		PackedStringArray(["uv_x", "uv_y"]),
		PackedStringArray(["0.1", "0.2"]),
		PackedStringArray(["0.3", "0.4"]),
		PackedStringArray(["0.5", "0.6"]),
	]
	var out: GNFixtureData = _cook_with(node, [dat]) as GNFixtureData
	GNTestAssert.assert_not_null(out, "CustomFIX produces output from DAT")
	GNTestAssert.assert_eq(out.led_count, 3, "3 rows = 3 LEDs")
	GNTestAssert.assert_approx(out.led_positions[0].x, 0.1, 0.001, "LED 0 x")
	GNTestAssert.assert_approx(out.led_positions[0].y, 0.2, 0.001, "LED 0 y")
	GNTestAssert.assert_approx(out.led_positions[2].x, 0.5, 0.001, "LED 2 x")
	GNTestAssert.assert_approx(out.led_positions[2].y, 0.6, 0.001, "LED 2 y")


func test_custom_fix_missing_columns() -> void:
	var node := _make_node(CustomFIX.new(), "custom1")
	var dat := GNTableData.new()
	dat.valid = true
	dat.has_header = true
	dat.table = [
		PackedStringArray(["x", "y"]),  # Wrong column names
		PackedStringArray(["0.1", "0.2"]),
	]
	_cook_with(node, [dat])
	GNTestAssert.assert_not_empty(node.node_warning, "warning on missing uv_x/uv_y columns")


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
	# Simulate two connected ports so _switch_clamp_index raises max to 1.
	# Dynamic inputs use a trailing empty slot, so port count = 3 with ports [0,1] connected.
	node.update_dynamic_inputs(PackedInt32Array([0, 1]))
	var fd0 := _make_fixture("first", 10)
	var fd1 := _make_fixture("second", 20)
	node.set_param_value("index", 0)
	node.execute_cook([fd0, fd1], 1)
	var out0: GNFixtureData = node.cached_output as GNFixtureData
	GNTestAssert.assert_not_null(out0, "switch output non-null")
	GNTestAssert.assert_eq(out0.fixture_name, "first", "index 0 selects first")
	node.set_param_value("index", 1)
	node.execute_cook([fd0, fd1], 2)  # different frame to avoid cache hit
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
# FixtureSamplerTOP -- GPU LED sampler
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
	# Provide a source TOP but no FIX inputs
	var tex := GNTextureData.new()
	tex.valid = true
	tex.texture = ImageTexture.create_from_image(
		Image.create(64, 64, false, Image.FORMAT_RGBA8))
	tex.resolution = Vector2i(64, 64)
	_cook_with(node, [tex])
	GNTestAssert.assert_not_empty(node.node_warning, "warning when no fixtures")


func test_fixture_sampler_rebuild_manifest() -> void:
	var node := _make_node(FixtureSamplerTOP.new(), "sampler1")
	var fd0 := _make_fixture("strip_a", 10, "rgb", 1)
	var fd1 := _make_fixture("strip_b", 20, "rgbw", 100)
	var fix_inputs: Array[GNFixtureData] = [fd0, fd1]
	node._rebuild_led_pos_texture(fix_inputs)
	GNTestAssert.assert_eq(node._total_leds, 30, "total LEDs = 10 + 20")
	GNTestAssert.assert_eq(node._max_channels, 4, "max channels = rgbw = 4")
	GNTestAssert.assert_size(node._fixture_manifest, 2, "2 fixture entries")
	# Check manifest offsets
	GNTestAssert.assert_eq(node._fixture_manifest[0]["offset"], 0, "first fixture offset 0")
	GNTestAssert.assert_eq(node._fixture_manifest[1]["offset"], 10, "second fixture offset 10")
	# Check manifest stores channel_layout
	GNTestAssert.assert_eq(node._fixture_manifest[0]["channel_layout"], "rgb", "manifest has layout")
	GNTestAssert.assert_eq(node._fixture_manifest[1]["channel_layout"], "rgbw", "manifest has layout")


func test_fixture_sampler_led_pos_texture() -> void:
	var node := _make_node(FixtureSamplerTOP.new(), "sampler1")
	var fd := _make_fixture("test", 5)
	fd.sample_extent = Vector2(0.02, 0.03)
	var fix_inputs: Array[GNFixtureData] = [fd]
	node._rebuild_led_pos_texture(fix_inputs)
	GNTestAssert.assert_not_null(node._led_pos_image, "LED pos image created")
	GNTestAssert.assert_eq(node._led_pos_image.get_width(), 5, "image width = total_leds")
	GNTestAssert.assert_eq(node._led_pos_image.get_height(), 1, "image height = 1")
	# Check first pixel stores UV + extent
	var px: Color = node._led_pos_image.get_pixel(0, 0)
	GNTestAssert.assert_approx(px.r, fd.led_positions[0].x, 0.001, "pixel r = uv_x")
	GNTestAssert.assert_approx(px.g, fd.led_positions[0].y, 0.001, "pixel g = uv_y")
	GNTestAssert.assert_approx(px.b, 0.02, 0.001, "pixel b = extent_x")
	GNTestAssert.assert_approx(px.a, 0.03, 0.001, "pixel a = extent_y")


func test_fixture_sampler_hash_changes() -> void:
	var fd := _make_fixture("test", 5)
	var h1: int = FixtureSamplerTOP._compute_fix_hash([fd])
	fd.fixture_name = "changed"
	var h2: int = FixtureSamplerTOP._compute_fix_hash([fd])
	GNTestAssert.assert_ne(h1, h2, "hash changes on name change")
	fd.fixture_name = "test"
	fd.led_count = 10
	fd.led_positions.resize(10)
	var h3: int = FixtureSamplerTOP._compute_fix_hash([fd])
	GNTestAssert.assert_ne(h1, h3, "hash changes on led_count change")


func test_fixture_sampler_port_structure() -> void:
	var node := _make_node(FixtureSamplerTOP.new(), "sampler1")
	# Input: port 0 = TOP source, port 1+ = FIX (dynamic)
	GNTestAssert.assert_gt(node.input_ports.size(), 0, "has input ports")
	GNTestAssert.assert_eq(node.input_ports[0].family, GNFamily.Type.TOP, "input port 0 is TOP")
	if node.input_ports.size() > 1:
		GNTestAssert.assert_eq(node.input_ports[1].family,
			GNFamily.string_to_type("FIX"), "input port 1 is FIX")
	# Output: port 0 must exist and be TOP (the packed result texture)
	GNTestAssert.assert_eq(node.output_ports.size(), 1, "has exactly 1 output port")
	GNTestAssert.assert_eq(node.output_ports[0].family, GNFamily.Type.TOP, "output port 0 is TOP")


# ============================================================================
# FixtureUnpackCHOP -- GPU readback to CHOP channels
# ============================================================================

func test_fixture_unpack_instantiate() -> void:
	var node := _make_node(FixtureUnpackCHOP.new(), "unpack1")
	GNTestAssert.assert_not_null(node, "FixtureUnpackCHOP instantiates")
	GNTestAssert.assert_eq(node.node_type, "fixture_unpack", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.CHOP, "family is CHOP")


func test_fixture_unpack_cook_null() -> void:
	var node := _make_node(FixtureUnpackCHOP.new(), "unpack1")
	_cook_no_input(node)
	GNTestAssert.assert_not_empty(node.node_warning, "warning when no input")


func test_fixture_unpack_no_manifest_metadata() -> void:
	var node := _make_node(FixtureUnpackCHOP.new(), "unpack1")
	# Texture with no fixture_manifest metadata should warn
	var tex_data := GNTextureData.new()
	tex_data.valid = true
	tex_data.texture = PlaceholderTexture2D.new()
	var result := _cook_with(node, [tex_data])
	GNTestAssert.assert_null(result, "null when no manifest metadata")
	GNTestAssert.assert_not_empty(node.node_warning, "warning about missing manifest")


func test_fixture_unpack_reads_metadata() -> void:
	var node := _make_node(FixtureUnpackCHOP.new(), "unpack1")
	# Build a tiny 3x2 image (3 channels, 2 LEDs) with known values
	var img := Image.create(3, 2, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(1.0, 0, 0))  # LED 0, ch R
	img.set_pixel(1, 0, Color(0.5, 0, 0))  # LED 0, ch G
	img.set_pixel(2, 0, Color(0.25, 0, 0)) # LED 0, ch B
	img.set_pixel(0, 1, Color(0.8, 0, 0))  # LED 1, ch R
	img.set_pixel(1, 1, Color(0.6, 0, 0))  # LED 1, ch G
	img.set_pixel(2, 1, Color(0.4, 0, 0))  # LED 1, ch B
	var tex := ImageTexture.create_from_image(img)
	var tex_data := GNTextureData.new()
	tex_data.valid = true
	tex_data.texture = tex
	tex_data.resolution = Vector2i(3, 2)
	tex_data.metadata["fixture_manifest"] = [{
		"name": "test_strip",
		"led_count": 2,
		"channels_per_led": 3,
		"channel_layout": "rgb",
		"dmx_start": 1,
		"offset": 0,
	}]
	var result: GNChannelData = _cook_with(node, [tex_data]) as GNChannelData
	GNTestAssert.assert_not_null(result, "unpack produces channel data")
	GNTestAssert.assert_true(result.channels.has("test_strip.r"), "has r channel")
	GNTestAssert.assert_true(result.channels.has("test_strip.g"), "has g channel")
	GNTestAssert.assert_true(result.channels.has("test_strip.b"), "has b channel")
	GNTestAssert.assert_eq(result.channels["test_strip.r"].size(), 2, "2 LEDs in r")
	# Values read from pixel.r component
	GNTestAssert.assert_approx(result.channels["test_strip.r"][0], 1.0, 0.01, "LED 0 R")
	GNTestAssert.assert_approx(result.channels["test_strip.g"][0], 0.5, 0.01, "LED 0 G")


# ============================================================================
# Cross-operator data flow (unit-level)
# ============================================================================

func test_strip_into_null_fix() -> void:
	var strip := _make_node(StripFIX.new(), "strip1")
	strip.set_param_value("led_count", 5)
	var strip_out: GNFixtureData = _cook_no_input(strip) as GNFixtureData
	var null_fix := _make_node(NullFIX.new(), "null1")
	var through: GNFixtureData = _cook_with(null_fix, [strip_out]) as GNFixtureData
	GNTestAssert.assert_not_null(through, "data flows through NullFIX")
	GNTestAssert.assert_eq(through.led_count, 5, "led_count preserved through null")


func test_multiple_fixtures_into_sampler_manifest() -> void:
	var sampler := _make_node(FixtureSamplerTOP.new(), "sampler1")
	var fd_rgb := _make_fixture("rgb_strip", 10, "rgb", 1)
	var fd_w := _make_fixture("w_strip", 5, "w", 31)
	var fix_inputs: Array[GNFixtureData] = [fd_rgb, fd_w]
	sampler._rebuild_led_pos_texture(fix_inputs)
	GNTestAssert.assert_eq(sampler._total_leds, 15, "total = 10 + 5")
	GNTestAssert.assert_eq(sampler._max_channels, 3, "max = rgb = 3")
	GNTestAssert.assert_eq(sampler._fixture_manifest[0]["name"], "rgb_strip", "first manifest name")
	GNTestAssert.assert_eq(sampler._fixture_manifest[1]["name"], "w_strip", "second manifest name")
	GNTestAssert.assert_eq(sampler._fixture_manifest[1]["channel_layout"], "w", "w layout preserved")


func test_recook_reuses_cached_data() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	var out1: GNFixtureData = _cook_no_input(node) as GNFixtureData
	var out2: GNFixtureData = _cook_no_input(node) as GNFixtureData
	GNTestAssert.assert_true(out1 == out2, "recook reuses same GNFixtureData instance")
