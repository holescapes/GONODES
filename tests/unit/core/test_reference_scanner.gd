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
