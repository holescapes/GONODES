extends Node
## Operator contract tests for the FIX family (gn_ext_pixel_mapper).
## Tests verify: instantiation, node_type, family, cook-null safety,
## and fixture geometry correctness for StripFIX and GridFIX.


func _make_node(node: GNNode, id: String) -> GNNode:
	node.initialize(id)
	return node


func _cook_no_input(node: GNNode) -> GNData:
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, 0)
	return node.cached_output


# ── FIX Primitives ─────────────────────────────────────────────────────────

func test_strip_fix_instantiate() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	GNTestAssert.assert_not_null(node, "StripFIX instantiates")
	GNTestAssert.assert_eq(node.node_type, "strip_fix", "node_type")
	GNTestAssert.assert_eq(node.family, GNFixtureBase.FIX_FAMILY, "family is FIX")

func test_strip_fix_cook_geometry() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, 0)
	var out: GNFixtureData = node.cached_output as GNFixtureData
	GNTestAssert.assert_not_null(out, "StripFIX produces output")
	GNTestAssert.assert_eq(out.led_count, 60, "default 60 LEDs")
	GNTestAssert.assert_eq(out.led_positions.size(), 60, "positions array size matches")
	GNTestAssert.assert_eq(out.channel_layout, "rgb", "default rgb layout")
	GNTestAssert.assert_eq(out.channels_per_led, 3, "rgb = 3 channels")

func test_strip_fix_endpoints() -> void:
	var node := _make_node(StripFIX.new(), "strip1")
	node.set_param_value("led_count", 10)
	node.set_param_value("uv_start", Vector2(0.0, 0.5))
	node.set_param_value("uv_end", Vector2(1.0, 0.5))
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, 0)
	var out: GNFixtureData = node.cached_output as GNFixtureData
	GNTestAssert.assert_not_null(out, "StripFIX produces output")
	GNTestAssert.assert_eq(out.led_positions[0], Vector2(0.0, 0.5), "first LED at uv_start")
	GNTestAssert.assert_eq(out.led_positions[9], Vector2(1.0, 0.5), "last LED at uv_end")

func test_grid_fix_instantiate() -> void:
	var node := _make_node(GridFIX.new(), "grid1")
	GNTestAssert.assert_not_null(node, "GridFIX instantiates")
	GNTestAssert.assert_eq(node.node_type, "grid_fix", "node_type")
	GNTestAssert.assert_eq(node.family, GNFixtureBase.FIX_FAMILY, "family is FIX")

func test_grid_fix_cook_geometry() -> void:
	var node := _make_node(GridFIX.new(), "grid1")
	node.set_param_value("cols", 4)
	node.set_param_value("rows", 4)
	var inputs: Array[GNData] = []
	node.execute_cook(inputs, 0)
	var out: GNFixtureData = node.cached_output as GNFixtureData
	GNTestAssert.assert_not_null(out, "GridFIX produces output")
	GNTestAssert.assert_eq(out.led_count, 16, "4×4 = 16 LEDs")
	GNTestAssert.assert_eq(out.led_positions.size(), 16, "positions array size")

func test_matrix_fix_instantiate() -> void:
	var node := _make_node(MatrixFIX.new(), "matrix1")
	GNTestAssert.assert_not_null(node, "MatrixFIX instantiates")
	GNTestAssert.assert_eq(node.node_type, "matrix_fix", "node_type")
	GNTestAssert.assert_eq(node.family, GNFixtureBase.FIX_FAMILY, "family is FIX")

func test_custom_fix_instantiate() -> void:
	var node := _make_node(CustomFIX.new(), "custom1")
	GNTestAssert.assert_not_null(node, "CustomFIX instantiates")
	GNTestAssert.assert_eq(node.node_type, "custom_fix", "node_type")

func test_custom_fix_cook_null() -> void:
	var node := _make_node(CustomFIX.new(), "custom1")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "CustomFIX cook-null no crash")

func test_file_in_fix_instantiate() -> void:
	var node := _make_node(FileInFIX.new(), "filein1")
	GNTestAssert.assert_not_null(node, "FileInFIX instantiates")
	GNTestAssert.assert_eq(node.node_type, "file_in_fix", "node_type")

func test_file_in_fix_cook_null() -> void:
	var node := _make_node(FileInFIX.new(), "filein1")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "FileInFIX cook-null no crash")

# ── FIX Utilities ──────────────────────────────────────────────────────────

func test_null_fix_instantiate() -> void:
	var node := _make_node(NullFIX.new(), "null1")
	GNTestAssert.assert_not_null(node, "NullFIX instantiates")
	GNTestAssert.assert_eq(node.node_type, "null_fix", "node_type")

func test_null_fix_cook_null() -> void:
	var node := _make_node(NullFIX.new(), "null1")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "NullFIX cook-null no crash")

func test_select_fix_instantiate() -> void:
	var node := _make_node(SelectFIX.new(), "sel1")
	GNTestAssert.assert_not_null(node, "SelectFIX instantiates")
	GNTestAssert.assert_eq(node.node_type, "select_fix", "node_type")

func test_select_fix_cook_null() -> void:
	var node := _make_node(SelectFIX.new(), "sel1")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "SelectFIX cook-null no crash")

func test_switch_fix_instantiate() -> void:
	var node := _make_node(SwitchFIX.new(), "switch1")
	GNTestAssert.assert_not_null(node, "SwitchFIX instantiates")
	GNTestAssert.assert_eq(node.node_type, "switch_fix", "node_type")

func test_switch_fix_cook_null() -> void:
	var node := _make_node(SwitchFIX.new(), "switch1")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "SwitchFIX cook-null no crash")

# ── Sampling / Output ──────────────────────────────────────────────────────

func test_fixture_sampler_instantiate() -> void:
	var node := _make_node(FixtureSamplerTOP.new(), "sampler1")
	GNTestAssert.assert_not_null(node, "FixtureSamplerTOP instantiates")
	GNTestAssert.assert_eq(node.node_type, "fixture_sampler", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.TOP, "family is TOP")

func test_fixture_sampler_cook_null() -> void:
	var node := _make_node(FixtureSamplerTOP.new(), "sampler1")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "FixtureSamplerTOP cook-null no crash")

func test_fixture_unpack_instantiate() -> void:
	var node := _make_node(FixtureUnpackCHOP.new(), "unpack1")
	GNTestAssert.assert_not_null(node, "FixtureUnpackCHOP instantiates")
	GNTestAssert.assert_eq(node.node_type, "fixture_unpack", "node_type")
	GNTestAssert.assert_eq(node.family, GNFamily.Type.CHOP, "family is CHOP")

func test_fixture_unpack_cook_null() -> void:
	var node := _make_node(FixtureUnpackCHOP.new(), "unpack1")
	_cook_no_input(node)
	GNTestAssert.assert_true(true, "FixtureUnpackCHOP cook-null no crash")

# ── GNFixtureData ──────────────────────────────────────────────────────────

func test_fixture_data_channels_for_layout() -> void:
	GNTestAssert.assert_eq(GNFixtureData.channels_for_layout("rgb"),  3, "rgb=3")
	GNTestAssert.assert_eq(GNFixtureData.channels_for_layout("rgbw"), 4, "rgbw=4")
	GNTestAssert.assert_eq(GNFixtureData.channels_for_layout("r"),    1, "r=1")

func test_fixture_data_duplicate() -> void:
	var fd := GNFixtureData.new()
	fd.fixture_name = "test"
	fd.led_count = 10
	fd.led_positions.resize(10)
	fd.led_positions[0] = Vector2(0.1, 0.2)
	var copy: GNFixtureData = fd.duplicate_data() as GNFixtureData
	GNTestAssert.assert_not_null(copy, "duplicate_data returns non-null")
	GNTestAssert.assert_eq(copy.fixture_name, "test", "name copied")
	GNTestAssert.assert_eq(copy.led_count, 10, "led_count copied")
	GNTestAssert.assert_eq(copy.led_positions[0], Vector2(0.1, 0.2), "positions copied")
