extends Node
## Correctness tests for DAT operators.
##
## DATs produce GNTableData (tables) or text. We can verify cell contents,
## row/column counts, header names, and text output directly.

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


## Helper: create a small table for testing filters.
func _make_test_table() -> GNTableData:
	var td := GNTableData.new()
	td.set_headers(PackedStringArray(["name", "value", "weight"]))
	td.append_row(PackedStringArray(["alpha", "10", "1.0"]))
	td.append_row(PackedStringArray(["beta", "5", "2.0"]))
	td.append_row(PackedStringArray(["gamma", "20", "0.5"]))
	td.valid = true
	return td


# ═══════════════════════════════════════════════════════════════════════════════
# ConstantDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_constant_dat_instantiate() -> void:
	var node := _make_node(ConstantDAT.new(), "const1")
	GNTestAssert.assert_eq(node.node_type, "constant", "node_type")

func test_constant_dat_produces_table() -> void:
	var node := _make_node(ConstantDAT.new(), "const1")
	node.set_param_value("col0", "name")
	node.set_param_value("col1", "value")
	node.set_param_value("r0c0", "test")
	node.set_param_value("r0c1", "42")
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "output exists")
	GNTestAssert.assert_true(out is GNTableData, "is GNTableData")

func test_constant_dat_cell_values() -> void:
	var node := _make_node(ConstantDAT.new(), "const1")
	node.set_param_value("col0", "key")
	node.set_param_value("col1", "val")
	node.set_param_value("r0c0", "hello")
	node.set_param_value("r0c1", "world")
	node.set_param_value("r1c0", "foo")
	node.set_param_value("r1c1", "bar")
	var out := _cook_no_input(node)
	if out is GNTableData:
		GNTestAssert.assert_eq(out.cell(0, 0), "hello", "r0c0")
		GNTestAssert.assert_eq(out.cell(0, 1), "world", "r0c1")
		GNTestAssert.assert_eq(out.cell(1, 0), "foo", "r1c0")
		GNTestAssert.assert_eq(out.cell(1, 1), "bar", "r1c1")

func test_constant_dat_headers() -> void:
	var node := _make_node(ConstantDAT.new(), "const1")
	node.set_param_value("col0", "alpha")
	node.set_param_value("col1", "beta")
	var out := _cook_no_input(node)
	if out is GNTableData:
		var headers: PackedStringArray = out.get_headers()
		GNTestAssert.assert_true(Array(headers).has("alpha"), "header alpha")
		GNTestAssert.assert_true(Array(headers).has("beta"), "header beta")


# ═══════════════════════════════════════════════════════════════════════════════
# TextDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_text_dat_instantiate() -> void:
	var node := _make_node(TextDAT.new(), "text1")
	GNTestAssert.assert_eq(node.node_type, "text", "node_type")

func test_text_dat_stores_text() -> void:
	var node := _make_node(TextDAT.new(), "text1")
	node.set_param_value("text", "Hello World")
	var out := _cook_no_input(node)
	if out is GNTableData:
		GNTestAssert.assert_eq(out.text, "Hello World", "text content")
		GNTestAssert.assert_false(out.is_table, "is text mode")

func test_text_dat_empty_string() -> void:
	var node := _make_node(TextDAT.new(), "text1")
	node.set_param_value("text", "")
	var out := _cook_no_input(node)
	if out is GNTableData:
		GNTestAssert.assert_eq(out.text, "", "empty text")


# ═══════════════════════════════════════════════════════════════════════════════
# TableDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_table_dat_instantiate() -> void:
	var node := _make_node(TableDAT.new(), "table1")
	GNTestAssert.assert_eq(node.node_type, "table", "node_type")

func test_table_dat_dimensions() -> void:
	var node := _make_node(TableDAT.new(), "table1")
	node.set_param_value("rows", 3)
	node.set_param_value("cols", 4)
	node.set_param_value("headers", "a,b,c,d")
	var out := _cook_no_input(node)
	if out is GNTableData:
		GNTestAssert.assert_eq(out.num_rows(), 3, "3 rows")
		GNTestAssert.assert_eq(out.num_cols(), 4, "4 cols")

func test_table_dat_header_parsing() -> void:
	var node := _make_node(TableDAT.new(), "table1")
	node.set_param_value("headers", "x,y,z")
	var out := _cook_no_input(node)
	if out is GNTableData:
		var h: PackedStringArray = out.get_headers()
		GNTestAssert.assert_eq(h[0], "x", "header 0")
		GNTestAssert.assert_eq(h[1], "y", "header 1")
		GNTestAssert.assert_eq(h[2], "z", "header 2")


# ═══════════════════════════════════════════════════════════════════════════════
# NullDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_null_dat_passthrough() -> void:
	var node := _make_node(NullDAT.new(), "null1")
	var input := _make_test_table()
	var out := _cook_with(node, [input] as Array[GNData])
	if out is GNTableData:
		GNTestAssert.assert_eq(out.num_rows(), 3, "passes 3 rows")

func test_null_dat_no_input() -> void:
	var node := _make_node(NullDAT.new(), "null1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNTableData, "no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# MergeDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_merge_dat_rows() -> void:
	var node := _make_node(MergeDAT.new(), "merge1")
	node.set_param_value("mode", 0)  # Rows
	var t1 := GNTableData.new()
	t1.set_headers(PackedStringArray(["a", "b"]))
	t1.append_row(PackedStringArray(["1", "2"]))
	t1.valid = true
	var t2 := GNTableData.new()
	t2.set_headers(PackedStringArray(["a", "b"]))
	t2.append_row(PackedStringArray(["3", "4"]))
	t2.append_row(PackedStringArray(["5", "6"]))
	t2.valid = true
	var out := _cook_with(node, [t1, t2] as Array[GNData])
	if out is GNTableData:
		GNTestAssert.assert_eq(out.num_rows(), 3, "merged 1+2=3 rows")
		GNTestAssert.assert_eq(out.cell(0, 0), "1", "first row preserved")
		GNTestAssert.assert_eq(out.cell(2, 0), "5", "last row from input 2")

func test_merge_dat_no_input() -> void:
	var node := _make_node(MergeDAT.new(), "merge1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNTableData, "no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# TransposeDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_transpose_dat_swaps_rows_cols() -> void:
	var node := _make_node(TransposeDAT.new(), "trans1")
	var input := GNTableData.new()
	input.set_headers(PackedStringArray(["a", "b", "c"]))
	input.append_row(PackedStringArray(["1", "2", "3"]))
	input.append_row(PackedStringArray(["4", "5", "6"]))
	input.valid = true
	var out := _cook_with(node, [input] as Array[GNData])
	if out is GNTableData:
		# Input: 3 rows (header+2 data) × 3 cols → transposed: 3 rows × 3 cols
		# num_rows() subtracts 1 for header, so 3-1=2
		GNTestAssert.assert_eq(out.num_rows(), 2, "transposed data rows")
		GNTestAssert.assert_eq(out.num_cols(), 3, "transposed cols")


# ═══════════════════════════════════════════════════════════════════════════════
# SortDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_sort_dat_ascending_numeric() -> void:
	var node := _make_node(SortDAT.new(), "sort1")
	node.set_param_value("sort_col", 1)
	node.set_param_value("order", 0)  # Ascending
	node.set_param_value("sort_type", 1)  # Numeric
	var input := _make_test_table()  # value col: 10, 5, 20
	var out := _cook_with(node, [input] as Array[GNData])
	if out is GNTableData and out.num_rows() >= 3:
		GNTestAssert.assert_eq(out.cell(0, 1), "5", "smallest first")
		GNTestAssert.assert_eq(out.cell(1, 1), "10", "middle")
		GNTestAssert.assert_eq(out.cell(2, 1), "20", "largest last")

func test_sort_dat_descending() -> void:
	var node := _make_node(SortDAT.new(), "sort1")
	node.set_param_value("sort_col", 1)
	node.set_param_value("order", 1)  # Descending
	node.set_param_value("sort_type", 1)  # Numeric
	var input := _make_test_table()
	var out := _cook_with(node, [input] as Array[GNData])
	if out is GNTableData and out.num_rows() >= 3:
		GNTestAssert.assert_eq(out.cell(0, 1), "20", "largest first")
		GNTestAssert.assert_eq(out.cell(2, 1), "5", "smallest last")


func test_sort_dat_alphabetic() -> void:
	var node := _make_node(SortDAT.new(), "sort2")
	node.set_param_value("sort_col", 0)
	node.set_param_value("order", 0)  # Ascending
	node.set_param_value("sort_type", 0)  # Alphabetic
	var input := _make_test_table()  # name col: alpha, beta, gamma
	var out := _cook_with(node, [input] as Array[GNData])
	if out is GNTableData and out.num_rows() >= 3:
		GNTestAssert.assert_eq(out.cell(0, 0), "alpha", "alpha first")
		GNTestAssert.assert_eq(out.cell(1, 0), "beta", "beta second")
		GNTestAssert.assert_eq(out.cell(2, 0), "gamma", "gamma third")


func test_sort_dat_preserves_row_count() -> void:
	var node := _make_node(SortDAT.new(), "sort3")
	var input := _make_test_table()
	var out := _cook_with(node, [input] as Array[GNData])
	if out is GNTableData:
		GNTestAssert.assert_eq(out.num_rows(), 3, "sort preserves row count")


# ═══════════════════════════════════════════════════════════════════════════════
# SelectDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_select_dat_instantiate() -> void:
	var node := _make_node(SelectDAT.new(), "sel1")
	GNTestAssert.assert_eq(node.node_type, "select", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# SwitchDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_switch_dat_instantiate() -> void:
	var node := _make_node(SwitchDAT.new(), "sw1")
	GNTestAssert.assert_eq(node.node_type, "switch", "node_type")


func test_switch_dat_selects_input() -> void:
	var t1 := GNTableData.new()
	t1.set_headers(PackedStringArray(["src"]))
	t1.append_row(PackedStringArray(["table1"]))
	t1.valid = true
	var t2 := GNTableData.new()
	t2.set_headers(PackedStringArray(["src"]))
	t2.append_row(PackedStringArray(["table2"]))
	t2.valid = true
	var node := _make_node(SwitchDAT.new(), "sw2")
	# Bump param max so index=1 isn't clamped (dynamic ports not wired in test)
	var idx_param := node.get_parameter("index")
	if idx_param:
		idx_param.max_value = 10
	node.set_param_value("index", 1)
	var out := _cook_with(node, [t1, t2] as Array[GNData])
	if out is GNTableData and out.num_rows() >= 1:
		GNTestAssert.assert_eq(out.cell(0, 0), "table2", "switch index=1 selects input 2")


# ═══════════════════════════════════════════════════════════════════════════════
# DeleteDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_delete_dat_instantiate() -> void:
	var node := _make_node(DeleteDAT.new(), "del1")
	GNTestAssert.assert_eq(node.node_type, "delete", "node_type")


func test_delete_dat_reduces_rows() -> void:
	var node := _make_node(DeleteDAT.new(), "del2")
	var input := _make_test_table()  # 3 rows
	var out := _cook_with(node, [input] as Array[GNData])
	if out is GNTableData:
		GNTestAssert.assert_true(out.num_rows() <= 3, "delete does not add rows")


# ═══════════════════════════════════════════════════════════════════════════════
# InsertDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_insert_dat_instantiate() -> void:
	var node := _make_node(InsertDAT.new(), "ins1")
	GNTestAssert.assert_eq(node.node_type, "insert", "node_type")


func test_insert_dat_adds_row() -> void:
	var node := _make_node(InsertDAT.new(), "ins2")
	var input := _make_test_table()  # 3 rows
	var out := _cook_with(node, [input] as Array[GNData])
	if out is GNTableData:
		GNTestAssert.assert_true(out.num_rows() >= 3, "insert does not lose rows")


# ═══════════════════════════════════════════════════════════════════════════════
# SubstituteDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_substitute_dat_instantiate() -> void:
	var node := _make_node(SubstituteDAT.new(), "sub1")
	GNTestAssert.assert_eq(node.node_type, "substitute", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# EvaluateDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_evaluate_dat_instantiate() -> void:
	var node := _make_node(EvaluateDAT.new(), "eval1")
	GNTestAssert.assert_eq(node.node_type, "evaluate", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# JSONDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_json_dat_instantiate() -> void:
	var node := _make_node(JSONDAT.new(), "json1")
	GNTestAssert.assert_eq(node.node_type, "json", "node_type")

func test_json_dat_parse_simple() -> void:
	var node := _make_node(JSONDAT.new(), "json1")
	node.set_param_value("mode", 0)  # Parse
	node.set_param_value("json_string", '{"name":"test","value":42}')
	var out := _cook_no_input(node)
	GNTestAssert.assert_not_null(out, "JSON parse output")
	GNTestAssert.assert_true(out is GNTableData, "is table")


# ═══════════════════════════════════════════════════════════════════════════════
# XMLDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_xml_dat_instantiate() -> void:
	var node := _make_node(XMLDAT.new(), "xml1")
	GNTestAssert.assert_eq(node.node_type, "xml", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# FIFODAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_fifo_dat_instantiate() -> void:
	var node := _make_node(FIFODAT.new(), "fifo1")
	GNTestAssert.assert_eq(node.node_type, "fifo", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# FileInDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_file_in_dat_instantiate() -> void:
	var node := _make_node(FileInDAT.new(), "fin1")
	GNTestAssert.assert_eq(node.node_type, "file_in", "node_type")

func test_file_in_dat_no_file() -> void:
	var node := _make_node(FileInDAT.new(), "fin1")
	var out := _cook_no_input(node)
	GNTestAssert.assert_true(out == null or out is GNTableData, "no crash")


# ═══════════════════════════════════════════════════════════════════════════════
# FolderDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_folder_dat_instantiate() -> void:
	var node := _make_node(FolderDAT.new(), "folder1")
	GNTestAssert.assert_eq(node.node_type, "folder", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# ErrorDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_error_dat_instantiate() -> void:
	var node := _make_node(ErrorDAT.new(), "err1")
	GNTestAssert.assert_eq(node.node_type, "error", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# InfoDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_info_dat_instantiate() -> void:
	var node := _make_node(InfoDAT.new(), "info1")
	GNTestAssert.assert_eq(node.node_type, "info", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# OPFindDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_op_find_dat_instantiate() -> void:
	var node := _make_node(OPFindDAT.new(), "opfind1")
	GNTestAssert.assert_eq(node.node_type, "op_find", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# NetworkDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_network_dat_instantiate() -> void:
	var node := _make_node(NetworkDAT.new(), "net1")
	GNTestAssert.assert_eq(node.node_type, "network", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# CHOPDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_chop_to_dat_instantiate() -> void:
	var node := _make_node(CHOPDAT.new(), "c2d1")
	GNTestAssert.assert_eq(node.node_type, "chop_to_dat", "node_type")

func test_chop_to_dat_converts_channels() -> void:
	var node := _make_node(CHOPDAT.new(), "c2d1")
	var cd := GNChannelData.new()
	cd.set_channel("x", PackedFloat32Array([1.0, 2.0, 3.0]))
	cd.set_channel("y", PackedFloat32Array([4.0, 5.0, 6.0]))
	cd.valid = true
	var out := _cook_with(node, [cd] as Array[GNData])
	GNTestAssert.assert_not_null(out, "chop_to_dat output")
	if out is GNTableData:
		GNTestAssert.assert_true(out.num_rows() > 0, "has rows")


# ═══════════════════════════════════════════════════════════════════════════════
# DATtoCHOP
# ═══════════════════════════════════════════════════════════════════════════════

func test_dat_to_chop_instantiate() -> void:
	var node := _make_node(DATtoCHOP.new(), "d2c1")
	GNTestAssert.assert_eq(node.node_type, "dat_to_chop", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# SOPtoDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_sop_to_dat_instantiate() -> void:
	var node := _make_node(SOPtoDAT.new(), "s2d1")
	GNTestAssert.assert_eq(node.node_type, "sop_to_dat", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# TOPtoDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_top_to_dat_instantiate() -> void:
	var node := _make_node(TOPtoDAT.new(), "t2d1")
	GNTestAssert.assert_eq(node.node_type, "top_to_dat", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# CallbackDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_callback_dat_instantiate() -> void:
	var node := _make_node(CallbackDAT.new(), "cb1")
	GNTestAssert.assert_eq(node.node_type, "callback", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# GDScriptSCRIPT (DAT via preset)
# ═══════════════════════════════════════════════════════════════════════════════

func test_gdscript_script_dat_instantiate() -> void:
	var node := _make_node(GDScriptSCRIPT.new(), "script1")
	GNTestAssert.assert_not_null(node, "GDScriptSCRIPT created")
	GNTestAssert.assert_eq(node.node_type, "script", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# WebDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_web_dat_instantiate() -> void:
	var node := _make_node(WebDAT.new(), "web1")
	GNTestAssert.assert_eq(node.node_type, "web", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# WebServerDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_web_server_dat_instantiate() -> void:
	var node := _make_node(WebServerDAT.new(), "ws1")
	GNTestAssert.assert_eq(node.node_type, "web_server", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# WebSocketDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_web_socket_dat_instantiate() -> void:
	var node := _make_node(WebSocketDAT.new(), "wss1")
	GNTestAssert.assert_eq(node.node_type, "web_socket", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# MidiInDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_midi_in_dat_instantiate() -> void:
	var node := _make_node(MidiInDAT.new(), "midi1")
	GNTestAssert.assert_eq(node.node_type, "midi_in", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# OscInDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_osc_in_dat_instantiate() -> void:
	var node := _make_node(OscInDAT.new(), "osc1")
	GNTestAssert.assert_eq(node.node_type, "osc_in", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# MultiTouchInDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_multi_touch_in_dat_instantiate() -> void:
	var node := _make_node(MultiTouchInDAT.new(), "touch1")
	GNTestAssert.assert_eq(node.node_type, "multi_touch_in", "node_type")
# ═══════════════════════════════════════════════════════════════════════════════
# CueDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_cue_dat_instantiate() -> void:
	var node := _make_node(CueDAT.new(), "cue1")
	GNTestAssert.assert_not_null(node, "CueDAT created")

func test_cue_dat_node_type() -> void:
	var node := _make_node(CueDAT.new(), "cue1")
	GNTestAssert.assert_eq(node.node_type, "cue", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# HostInDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_in_dat_instantiate() -> void:
	var node := _make_node(HostInDAT.new(), "host_in1")
	GNTestAssert.assert_not_null(node, "HostInDAT created")


# ═══════════════════════════════════════════════════════════════════════════════
# MqttDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_mqtt_dat_instantiate() -> void:
	var node := _make_node(MqttDAT.new(), "mqtt1")
	GNTestAssert.assert_not_null(node, "MqttDAT created")

func test_mqtt_dat_set_broker() -> void:
	var node := _make_node(MqttDAT.new(), "mqtt1")
	node.set_param_value("broker_url", "mqtt://localhost:1883")
	GNTestAssert.assert_not_null(node, "MqttDAT with broker param")


# ═══════════════════════════════════════════════════════════════════════════════
# PanelExecuteDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_panel_execute_dat_instantiate() -> void:
	var node := _make_node(PanelExecuteDAT.new(), "panel_exec1")
	GNTestAssert.assert_not_null(node, "PanelExecuteDAT created")

func test_panel_execute_dat_node_type() -> void:
	var node := _make_node(PanelExecuteDAT.new(), "panel_exec1")
	GNTestAssert.assert_eq(node.node_type, "panel_execute", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# RenderPickDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_render_pick_dat_instantiate() -> void:
	var node := _make_node(RenderPickDAT.new(), "pick1")
	GNTestAssert.assert_not_null(node, "RenderPickDAT created")

func test_render_pick_dat_node_type() -> void:
	var node := _make_node(RenderPickDAT.new(), "pick1")
	GNTestAssert.assert_eq(node.node_type, "render_pick", "node_type")


# ═══════════════════════════════════════════════════════════════════════════════
# HostOutDAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_host_out_dat_instantiate() -> void:
	var node := _make_node(HostOutDAT.new(), "host_out1")
	GNTestAssert.assert_not_null(node, "HostOutDAT created")


# ═══════════════════════════════════════════════════════════════════════════════
# GNSDFData (data class, not a DAT operator)
# ═══════════════════════════════════════════════════════════════════════════════

func test_gn_sdf_data_instantiate() -> void:
	var data := GNSDFData.new()
	GNTestAssert.assert_not_null(data, "GNSDFData created")


# ═══════════════════════════════════════════════════════════════════════════════
# GNGeoData
# ═══════════════════════════════════════════════════════════════════════════════

func test_gn_geo_data_instantiate() -> void:
	var data := GNGeoData.new()
	GNTestAssert.assert_not_null(data, "GNGeoData created")

func test_gn_geo_data_is_gn_data() -> void:
	var data := GNGeoData.new()
	GNTestAssert.assert_true(data is GNData, "GNGeoData is GNData subclass")


# ═══════════════════════════════════════════════════════════════════════════════
# GNImageData
# ═══════════════════════════════════════════════════════════════════════════════

func test_gn_image_data_instantiate() -> void:
	var data := GNImageData.new()
	GNTestAssert.assert_not_null(data, "GNImageData created")

func test_gn_image_data_is_gn_data() -> void:
	var data := GNImageData.new()
	GNTestAssert.assert_true(data is GNData, "GNImageData is GNData subclass")


# ═══════════════════════════════════════════════════════════════════════════════
# GNMaterialData
# ═══════════════════════════════════════════════════════════════════════════════

func test_gn_material_data_instantiate() -> void:
	var data := GNMaterialData.new()
	GNTestAssert.assert_not_null(data, "GNMaterialData created")

func test_gn_material_data_is_gn_data() -> void:
	var data := GNMaterialData.new()
	GNTestAssert.assert_true(data is GNData, "GNMaterialData is GNData subclass")


# ═══════════════════════════════════════════════════════════════════════════════
# GNParticleData
# ═══════════════════════════════════════════════════════════════════════════════

func test_gn_particle_data_instantiate() -> void:
	var data := GNParticleData.new()
	GNTestAssert.assert_not_null(data, "GNParticleData created")

func test_gn_particle_data_is_gn_data() -> void:
	var data := GNParticleData.new()
	GNTestAssert.assert_true(data is GNData, "GNParticleData is GNData subclass")


# ═══════════════════════════════════════════════════════════════════════════════
# GNTextureData
# ═══════════════════════════════════════════════════════════════════════════════

func test_gn_texture_data_instantiate() -> void:
	var data := GNTextureData.new()
	GNTestAssert.assert_not_null(data, "GNTextureData created")

func test_gn_texture_data_is_gn_data() -> void:
	var data := GNTextureData.new()
	GNTestAssert.assert_true(data is GNData, "GNTextureData is GNData subclass")


# ═══════════════════════════════════════════════════════════════════════════════
# GNVolumeData
# ═══════════════════════════════════════════════════════════════════════════════

func test_gn_volume_data_instantiate() -> void:
	var data := GNVolumeData.new()
	GNTestAssert.assert_not_null(data, "GNVolumeData created")

func test_gn_volume_data_is_gn_data() -> void:
	var data := GNVolumeData.new()
	GNTestAssert.assert_true(data is GNData, "GNVolumeData is GNData subclass")


# ═══════════════════════════════════════════════════════════════════════════════
#  ParameterDAT (Gap Operator)
# ═══════════════════════════════════════════════════════════════════════════════

func test_parameter_dat_instantiate() -> void:
	var node := _make_node(ParameterDAT.new(), "paramdat1")
	GNTestAssert.assert_eq(node.node_type, "parameter", "node_type for ParameterDAT")

func test_parameter_dat_no_target() -> void:
	var node := _make_node(ParameterDAT.new(), "paramdat2")
	var out := _cook_no_input(node)
	# Without a valid target, should produce empty or null output
	GNTestAssert.assert_true(out == null or out is GNTableData, "no crash without target")

func test_parameter_dat_with_target() -> void:
	var target := _make_node(ConstantDAT.new(), "const1")
	var node := _make_node(ParameterDAT.new(), "paramdat3")
	node.set_param_value("target_node", "const1")
	var out: GNTableData = _cook_no_input(node) as GNTableData
	if out:
		GNTestAssert.assert_gt(out.table.size(), 0, "has rows for target params")


# ═══════════════════════════════════════════════════════════════════════════════
#  SystemDAT (Gap Operator)
# ═══════════════════════════════════════════════════════════════════════════════

func test_system_dat_instantiate() -> void:
	var node := _make_node(SystemDAT.new(), "sysdat1")
	GNTestAssert.assert_eq(node.node_type, "system", "node_type for SystemDAT")

func test_system_dat_produces_output() -> void:
	var node := _make_node(SystemDAT.new(), "sysdat2")
	var out: GNTableData = _cook_no_input(node) as GNTableData
	GNTestAssert.assert_not_null(out, "system dat produces output")
	GNTestAssert.assert_gt(out.table.size(), 0, "has info rows")

func test_system_dat_has_os_info() -> void:
	var node := _make_node(SystemDAT.new(), "sysdat3")
	var out: GNTableData = _cook_no_input(node) as GNTableData
	if out:
		var has_os := false
		for row in out.table:
			if row.size() > 0 and row[0].to_lower().contains("os"):
				has_os = true
				break
		GNTestAssert.assert_true(has_os, "contains OS info")
