extends Node
## Unit tests for GNReferenceScanner — read/write/@affects parsing.


func test_scan_read_ids_from_expression() -> void:
	var refs := GNReferenceScanner.scan_read_ids('chop("lfo1", "out", 0)', "reader")
	GNTestAssert.assert_eq(refs.size(), 1, "one read ref")
	GNTestAssert.assert_eq(refs[0], "lfo1", "lfo1 referenced")


func test_scan_write_targets_set_par() -> void:
	var writes := GNReferenceScanner.scan_write_targets(
			'set_par("target", "value0", 2.0)', "writer")
	GNTestAssert.assert_eq(writes.size(), 1, "one write")
	GNTestAssert.assert_eq(writes[0]["target_id"], "target", "target id")


func test_parse_affects_annotation() -> void:
	var code := "# @affects mixer:gain\nfunc cook():\n\tpass"
	var aff := GNReferenceScanner.parse_affects_annotations(code)
	GNTestAssert.assert_eq(aff.size(), 1, "one @affects")
	GNTestAssert.assert_eq(aff[0]["target_id"], "mixer", "node id")
	GNTestAssert.assert_eq(aff[0]["param"], "gain", "param name")


func test_scan_network_reads_and_writes() -> void:
	var net := GNNetwork.new()
	var reader := ConstantCHOP.new()
	reader.initialize("reader")
	var p := GNParameter.create_float("x", 0.0)
	p.set_expression('chop("lfo1", "out", 0)')
	reader.add_parameter(p)
	net.add_node(reader)

	var writer := GDScriptSCRIPT.new()
	writer.initialize("writer")
	writer.set_param_value("code", """# @affects lfo1
func cook():
	set_par("lfo1", "value0", 1.0)
""".strip_edges())
	net.add_node(writer)

	var scan := GNReferenceScanner.scan_network(net)
	GNTestAssert.assert_true(scan["reads"].has("reader"), "reader in reads map")
	GNTestAssert.assert_true("lfo1" in scan["reads"]["reader"], "reader reads lfo1")
	var one := GNReferenceScanner.scan_node(reader)
	GNTestAssert.assert_eq(one["calls"].size(), 1, "one call")
	GNTestAssert.assert_eq(one["calls"][0]["func"], "chop", "call name")
	GNTestAssert.assert_eq(one["calls"][0]["target_id"], "lfo1", "call target")
	GNTestAssert.assert_true(scan["writes"].has("writer"), "writer in writes map")

	var readers := GNReferenceScanner.find_readers_of(net, "lfo1")
	GNTestAssert.assert_true(readers.has("reader"), "lfo1 referenced by reader")


func test_read_edge_details_stay_on_the_call_that_names_the_node() -> void:
	GNReferenceScanner.configure_call_funcs(PackedStringArray(["set_par"]))
	var code := """func cook():
	set_par("folder_display", "path", str(par("assets_root")).rstrip("/"))
	set_par("hud_comp_meta", "opacity", _meta_op)
	set_par("hud_title", "text", "BIT ROTS")
	set_par("hud_meta", "text", meta_txt)
"""
	var details := GNReferenceScanner.build_read_edge_details(code, "controller")
	var meta: Array = details["controller→hud_comp_meta"]
	GNTestAssert.assert_eq(meta.size(), 1, "one call on hud_comp_meta")
	GNTestAssert.assert_true(str(meta[0]).contains("\"opacity\""), "hud_comp_meta gets opacity")
	GNTestAssert.assert_false(str(meta[0]).contains("\"text\""), "hud_comp_meta does not get text")
	var title: Array = details["controller→hud_title"]
	GNTestAssert.assert_eq(title.size(), 1, "one call on hud_title")
	GNTestAssert.assert_true(str(title[0]).contains("\"text\""), "hud_title gets text")
