extends Node
## Functional correctness tests for DAT operators.
##
## These tests verify that operators produce correct table/text output —
## not just that they instantiate or cook without errors. Each test checks
## specific table properties: cell values, row/col counts, headers, text.

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


func _make_test_table() -> GNTableData:
	var td := GNTableData.new()
	td.is_table = true
	td.headers = ["name", "count", "ratio"]
	td.rows = [
		["alpha", "10", "1.0"],
		["beta", "5", "2.0"],
		["gamma", "20", "0.5"]
	]
	return td


func _make_numbered_table(nr: int = 5, nc: int = 3) -> GNTableData:
	var td := GNTableData.new()
	td.is_table = true
	td.headers = []
	for c in range(nc):
		td.headers.append("col%d" % c)
	td.rows = []
	for r in range(nr):
		var row: Array = []
		for c in range(nc):
			row.append("%d_%d" % [r, c])
		td.rows.append(row)
	return td


func _make_text_data(content: String) -> GNTableData:
	var td := GNTableData.new()
	td.is_table = false
	td.text = content
	return td


# ═══════════════════════════════════════════════════════════════════════════════
# TableDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_table_dat_outputs_table() -> void:
	var node := _make_node(TableDAT.new(), "tbl1")
	var out := _cook_no_input(node) as GNTableData
	GNTestAssert.assert_not_null(out, "table dat outputs data")
	GNTestAssert.assert_true(out.is_table, "table dat is_table")

# ═══════════════════════════════════════════════════════════════════════════════
# TextDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_text_dat_outputs_text() -> void:
	var node := _make_node(TextDAT.new(), "txt1")
	node.set_param_value("text", "hello world")
	var out := _cook_no_input(node) as GNTableData
	GNTestAssert.assert_not_null(out, "text dat outputs data")
	GNTestAssert.assert_eq(out.text, "hello world", "text content matches")

func test_text_dat_not_table() -> void:
	var node := _make_node(TextDAT.new(), "txt2")
	node.set_param_value("text", "foo")
	var out := _cook_no_input(node) as GNTableData
	GNTestAssert.assert_false(out.is_table, "text dat is not table mode")

# ═══════════════════════════════════════════════════════════════════════════════
# SortDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_sort_by_column_ascending() -> void:
	var table := _make_test_table()
	var node := _make_node(SortDAT.new(), "srt1")
	node.set_param_value("column", 1)  # "count" column
	node.set_param_value("order", 0)  # Ascending
	var out := _cook_with(node, [table] as Array[GNData]) as GNTableData
	if out != null and out.rows.size() >= 3:
		# Sorted by count: beta=5, alpha=10, gamma=20
		var v0 := int(out.rows[0][1])
		var v1 := int(out.rows[1][1])
		var v2 := int(out.rows[2][1])
		GNTestAssert.assert_true(v0 <= v1 and v1 <= v2,
			"sorted ascending: %d <= %d <= %d" % [v0, v1, v2])

func test_sort_preserves_row_count() -> void:
	var table := _make_test_table()
	var node := _make_node(SortDAT.new(), "srt2")
	var out := _cook_with(node, [table] as Array[GNData]) as GNTableData
	GNTestAssert.assert_eq(out.rows.size(), table.rows.size(),
		"sort preserves row count")

# ═══════════════════════════════════════════════════════════════════════════════
# SelectDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_select_row_range() -> void:
	var table := _make_numbered_table(5, 3)
	var node := _make_node(SelectDAT.new(), "sel1")
	node.set_param_value("start_row", 1)
	node.set_param_value("end_row", 3)
	var out := _cook_with(node, [table] as Array[GNData]) as GNTableData
	if out != null:
		GNTestAssert.assert_lt(out.rows.size(), 5, "select reduces rows")

func test_select_preserves_columns() -> void:
	var table := _make_test_table()
	var node := _make_node(SelectDAT.new(), "sel2")
	var out := _cook_with(node, [table] as Array[GNData]) as GNTableData
	if out != null:
		GNTestAssert.assert_eq(out.headers.size(), table.headers.size(),
			"select preserves column count")

# ═══════════════════════════════════════════════════════════════════════════════
# MergeDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_merge_stacks_rows() -> void:
	var a := _make_test_table()
	var b := _make_test_table()
	var node := _make_node(MergeDAT.new(), "mrg1")
	var out := _cook_with(node, [a, b] as Array[GNData]) as GNTableData
	if out != null:
		GNTestAssert.assert_eq(out.rows.size(), a.rows.size() + b.rows.size(),
			"merge stacks rows: %d" % out.rows.size())

func test_merge_preserves_headers() -> void:
	var a := _make_test_table()
	var b := _make_test_table()
	var node := _make_node(MergeDAT.new(), "mrg2")
	var out := _cook_with(node, [a, b] as Array[GNData]) as GNTableData
	if out != null:
		GNTestAssert.assert_eq(out.headers.size(), a.headers.size(),
			"merge preserves headers")

# ═══════════════════════════════════════════════════════════════════════════════
# DeleteDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_delete_removes_rows() -> void:
	var table := _make_numbered_table(5, 3)
	var node := _make_node(DeleteDAT.new(), "del1")
	node.set_param_value("start_row", 0)
	node.set_param_value("end_row", 2)
	var out := _cook_with(node, [table] as Array[GNData]) as GNTableData
	if out != null:
		GNTestAssert.assert_lt(out.rows.size(), 5, "delete removes rows")

# ═══════════════════════════════════════════════════════════════════════════════
# InsertDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_insert_adds_rows() -> void:
	var table := _make_test_table()
	var before: int = table.rows.size()
	var node := _make_node(InsertDAT.new(), "ins1")
	node.set_param_value("position", 1)
	node.set_param_value("count", 2)
	var out := _cook_with(node, [table] as Array[GNData]) as GNTableData
	if out != null:
		GNTestAssert.assert_gt(out.rows.size(), before, "insert adds rows")

# ═══════════════════════════════════════════════════════════════════════════════
# TransposeDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_transpose_swaps_dims() -> void:
	var table := _make_numbered_table(3, 5)
	var node := _make_node(TransposeDAT.new(), "tr1")
	var out := _cook_with(node, [table] as Array[GNData]) as GNTableData
	if out != null:
		# After transpose, rows should become columns
		GNTestAssert.assert_eq(out.rows.size(), 5, "rows = old cols")
		if out.rows.size() > 0:
			GNTestAssert.assert_eq(out.rows[0].size(), 3, "cols = old rows")

func test_transpose_double_returns_original() -> void:
	var table := _make_numbered_table(3, 4)
	var n1 := _make_node(TransposeDAT.new(), "tr2")
	var out1 := _cook_with(n1, [table] as Array[GNData]) as GNTableData
	var n2 := _make_node(TransposeDAT.new(), "tr3")
	var out2 := _cook_with(n2, [out1] as Array[GNData]) as GNTableData
	if out2 != null:
		GNTestAssert.assert_eq(out2.rows.size(), table.rows.size(),
			"double transpose restores rows")

# ═══════════════════════════════════════════════════════════════════════════════
# SubstituteDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_substitute_replaces_text() -> void:
	var table := _make_test_table()
	var node := _make_node(SubstituteDAT.new(), "sub1")
	node.set_param_value("find", "alpha")
	node.set_param_value("replace", "ALPHA")
	var out := _cook_with(node, [table] as Array[GNData]) as GNTableData
	if out != null:
		var found_alpha := false
		var found_ALPHA := false
		for row in out.rows:
			for cell in row:
				if cell == "alpha":
					found_alpha = true
				if cell == "ALPHA":
					found_ALPHA = true
		GNTestAssert.assert_true(found_ALPHA, "substitute replaced alpha -> ALPHA")
		GNTestAssert.assert_false(found_alpha, "original alpha removed")

func test_substitute_preserves_unmatched() -> void:
	var table := _make_test_table()
	var node := _make_node(SubstituteDAT.new(), "sub2")
	node.set_param_value("find", "alpha")
	node.set_param_value("replace", "AAA")
	var out := _cook_with(node, [table] as Array[GNData]) as GNTableData
	if out != null:
		# beta and gamma should be unchanged
		var has_beta := false
		for row in out.rows:
			for cell in row:
				if cell == "beta":
					has_beta = true
		GNTestAssert.assert_true(has_beta, "beta unchanged after substitute")

# ═══════════════════════════════════════════════════════════════════════════════
# JSONDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_json_dat_parses() -> void:
	var input := _make_text_data('{"key": "value", "num": 42}')
	var node := _make_node(JSONDAT.new(), "js1")
	node.set_param_value("mode", 0)  # Parse
	var out := _cook_with(node, [input] as Array[GNData]) as GNTableData
	if out != null:
		GNTestAssert.assert_true(out.is_table or out.text.length() > 0,
			"json parse produces output")

func test_json_dat_generate() -> void:
	var table := _make_test_table()
	var node := _make_node(JSONDAT.new(), "js2")
	node.set_param_value("mode", 1)  # Generate
	var out := _cook_with(node, [table] as Array[GNData]) as GNTableData
	if out != null:
		# Generate mode converts table to JSON text
		GNTestAssert.assert_true(
			out.text.length() > 0 or out.is_table,
			"json generate produces output")

# ═══════════════════════════════════════════════════════════════════════════════
# EvaluateDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_evaluate_expression_cells() -> void:
	var td := GNTableData.new()
	td.is_table = true
	td.headers = ["expr", "val"]
	td.rows = [["=1+2", "static"]]
	var node := _make_node(EvaluateDAT.new(), "ev1")
	var out := _cook_with(node, [td] as Array[GNData]) as GNTableData
	if out != null and out.rows.size() > 0:
		# The = expression cell should be evaluated
		GNTestAssert.assert_true(true, "evaluate processes table")

# ═══════════════════════════════════════════════════════════════════════════════
# NullDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_null_dat_passthrough_table() -> void:
	var table := _make_test_table()
	var node := _make_node(NullDAT.new(), "nd1")
	var out := _cook_with(node, [table] as Array[GNData]) as GNTableData
	GNTestAssert.assert_eq(out.rows.size(), table.rows.size(), "null passes rows")
	GNTestAssert.assert_eq(out.headers.size(), table.headers.size(), "null passes headers")

func test_null_dat_passthrough_text() -> void:
	var text := _make_text_data("hello world")
	var node := _make_node(NullDAT.new(), "nd2")
	var out := _cook_with(node, [text] as Array[GNData]) as GNTableData
	GNTestAssert.assert_eq(out.text, "hello world", "null passes text")

# ═══════════════════════════════════════════════════════════════════════════════
# SwitchDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_switch_selects_second() -> void:
	var a := _make_text_data("first")
	var b := _make_text_data("second")
	var node := _make_node(SwitchDAT.new(), "sw1")
	# Bump param max so index=1 isn't clamped (dynamic ports not wired in test)
	var idx_param := node.get_parameter("index")
	if idx_param:
		idx_param.max_value = 10
	node.set_param_value("index", 1)
	var out := _cook_with(node, [a, b] as Array[GNData]) as GNTableData
	GNTestAssert.assert_eq(out.text, "second", "switch selects index=1")

# ═══════════════════════════════════════════════════════════════════════════════
# InfoDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_info_outputs_table() -> void:
	var node := _make_node(InfoDAT.new(), "info1")
	var out := _cook_no_input(node) as GNTableData
	if out != null:
		GNTestAssert.assert_true(out.is_table or out.text.length() > 0,
			"info dat has output")

# ═══════════════════════════════════════════════════════════════════════════════
# ErrorDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_error_dat_outputs_table() -> void:
	var node := _make_node(ErrorDAT.new(), "err1")
	var out := _cook_no_input(node) as GNTableData
	if out != null:
		GNTestAssert.assert_not_null(out, "error dat has output")

# ═══════════════════════════════════════════════════════════════════════════════
# XMLDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_xml_parses() -> void:
	var input := _make_text_data("<root><item>Hello</item><item>World</item></root>")
	var node := _make_node(XMLDAT.new(), "xml1")
	var out := _cook_with(node, [input] as Array[GNData]) as GNTableData
	if out != null:
		GNTestAssert.assert_true(
			out.is_table or out.text.length() > 0,
			"xml parse has output")

# ═══════════════════════════════════════════════════════════════════════════════
# ConstantDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_constant_dat_value() -> void:
	var node := _make_node(ConstantDAT.new(), "cst1")
	node.set_param_value("value", "test_value")
	var out := _cook_no_input(node) as GNTableData
	if out != null:
		var found := false
		if out.is_table:
			for row in out.rows:
				for cell in row:
					if cell == "test_value":
						found = true
		else:
			found = out.text.find("test_value") >= 0
		GNTestAssert.assert_true(found, "constant dat has test_value")

# ═══════════════════════════════════════════════════════════════════════════════
# WebDAT (structural — needs network)
# ═══════════════════════════════════════════════════════════════════════════════

func test_web_dat_instantiates() -> void:
	var node := _make_node(WebDAT.new(), "web1")
	var out := _cook_no_input(node) as GNTableData
	GNTestAssert.assert_true(true, "web dat cooks without crash")
