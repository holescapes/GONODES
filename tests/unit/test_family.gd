extends Node
## Architecture tests for GNFamily — verifies all 13 core family types,
## name resolution, and the _CORE_FAMILY_IDS registry.


func test_all_13_core_families_exist() -> void:
	var expected := [
		"TOP", "IMG", "CHOP", "SOP", "POP", "DAT",
		"MAT", "COMP", "VOL", "UI", "OUT", "SCRIPT", "NET",
	]
	for name in expected:
		var fam := GNFamily.string_to_type(name)
		GNTestAssert.assert_true(fam >= 0, "%s resolves to valid type" % name)


func test_net_family_enum_value() -> void:
	GNTestAssert.assert_eq(GNFamily.Type.NET, 12, "NET is enum index 12")


func test_string_to_type_case_insensitive() -> void:
	GNTestAssert.assert_eq(
		GNFamily.string_to_type("top"),
		GNFamily.Type.TOP,
		"lowercase 'top' resolves")
	GNTestAssert.assert_eq(
		GNFamily.string_to_type("Net"),
		GNFamily.Type.NET,
		"mixed case 'Net' resolves")


func test_string_to_type_unknown_returns_fallback() -> void:
	var result := GNFamily.string_to_type("NONEXISTENT_FAMILY_XYZ")
	GNTestAssert.assert_eq(result, GNFamily.Type.COMP, "unknown family falls back to COMP")


func test_get_family_name_round_trip() -> void:
	var names := ["TOP", "IMG", "CHOP", "SOP", "POP", "DAT",
		"MAT", "COMP", "VOL", "UI", "OUT", "SCRIPT", "NET"]
	for name in names:
		var fam := GNFamily.string_to_type(name)
		var resolved_name := GNFamily.get_family_name(fam)
		GNTestAssert.assert_eq(resolved_name, name, "round-trip for %s" % name)


func test_core_family_ids_count() -> void:
	GNTestAssert.assert_eq(
		GNFamily._CORE_FAMILY_IDS.size(), 13,
		"exactly 13 core family IDs")


func test_data_families_exclude_net() -> void:
	# NET is classification-only — should not appear in get_data_families()
	var data_fams := GNFamily.get_data_families()
	for df in data_fams:
		GNTestAssert.assert_true(
			df != GNFamily.Type.NET,
			"NET not in data families")
