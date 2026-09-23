extends Node
## Phase 4e — GNPattern against the example tables in dev_docs/PATTERNS.md.
##
## Sections covered: 1.4, 2.4, 3.1–3.5, 4.1–4.4, 5.2–5.5, 6.1–6.5.
## A failure here is either an engine bug or a stale doc row. Do not weaken
## an assertion to match a surprise result without recording it in PRE-BETA_AUDIT.md.


func _chans() -> PackedStringArray:
	return PackedStringArray([
		"tx", "ty", "tz", "rx", "ry", "rz",
		"scale_x", "scale_y", "scale_z", "blend1", "blend2", "temp",
	])


func _chans2() -> PackedStringArray:
	return PackedStringArray([
		"tx", "ty", "tz", "rx", "ry", "rz", "blend1", "blend2", "temp_debug",
	])


func _assert_filter(names: PackedStringArray, pattern: String, expected: PackedStringArray, msg: String) -> void:
	var actual := GNPattern.filter(names, pattern)
	GNTestAssert.assert_eq(actual.size(), expected.size(), "%s count (got %s)" % [msg, " ".join(actual)])
	for n in expected:
		GNTestAssert.assert_true(actual.has(n), "%s missing '%s' (got %s)" % [msg, n, " ".join(actual)])


func _assert_indices(range_str: String, count: int, expected: Array, msg: String) -> void:
	var actual := GNPattern.parse_index_range(range_str, count)
	GNTestAssert.assert_eq(actual.size(), expected.size(), "%s count (got %s)" % [msg, str(actual)])
	for i in range(mini(actual.size(), expected.size())):
		GNTestAssert.assert_eq(actual[i], expected[i], "%s [%d]" % [msg, i])


func _assert_expand(pattern: String, expected: PackedStringArray, msg: String) -> void:
	var actual := GNPattern.expand(pattern)
	GNTestAssert.assert_eq(actual.size(), expected.size(), "%s count (got %s)" % [msg, " ".join(actual)])
	for i in range(mini(actual.size(), expected.size())):
		GNTestAssert.assert_eq(actual[i], expected[i], "%s [%d]" % [msg, i])


# ─── §1.4 name matching ──────────────────────────────────────────────────────

func test_pat_14_wildcards() -> void:
	var names := _chans()
	_assert_filter(names, "*", names, "§1.4 *")
	_assert_filter(names, "t?", PackedStringArray(["tx", "ty", "tz"]), "§1.4 t?")
	_assert_filter(names, "?x", PackedStringArray(["tx", "rx"]), "§1.4 ?x")
	_assert_filter(names, "[tr]?", PackedStringArray(["tx", "ty", "tz", "rx", "ry", "rz"]), "§1.4 [tr]?")
	_assert_filter(names, "scale_*", PackedStringArray(["scale_x", "scale_y", "scale_z"]), "§1.4 scale_*")
	_assert_filter(names, "blend*", PackedStringArray(["blend1", "blend2"]), "§1.4 blend*")
	_assert_filter(names, "*_z", PackedStringArray(["scale_z"]), "§1.4 *_z")
	_assert_filter(names, "[!t]*", PackedStringArray([
		"rx", "ry", "rz", "scale_x", "scale_y", "scale_z", "blend1", "blend2",
	]), "§1.4 [!t]*")


# ─── §2.4 multi-pattern ──────────────────────────────────────────────────────

func test_pat_24_csv_and_exclusion() -> void:
	var names := _chans2()
	_assert_filter(names, "tx, ry", PackedStringArray(["tx", "ry"]), "§2.4 exact csv")
	_assert_filter(names, "t*, r*", PackedStringArray([
		"tx", "ty", "tz", "rx", "ry", "rz", "temp_debug",
	]), "§2.4 t*, r*")
	_assert_filter(names, "t*, !temp*", PackedStringArray(["tx", "ty", "tz"]), "§2.4 exclude prefix")
	_assert_filter(names, "*, !blend*", PackedStringArray([
		"tx", "ty", "tz", "rx", "ry", "rz", "temp_debug",
	]), "§2.4 exclude blend")
	_assert_filter(names, "!tz, !rz", PackedStringArray([
		"tx", "ty", "rx", "ry", "blend1", "blend2", "temp_debug",
	]), "§2.4 exclude-only implies *")
	_assert_filter(names, "blend[12]", PackedStringArray(["blend1", "blend2"]), "§2.4 char class")


# ─── §3 index ranges ─────────────────────────────────────────────────────────

func test_pat_31_index_syntax() -> void:
	_assert_indices("5", 20, [5], "§3.1 exact")
	_assert_indices("3-7", 20, [3, 4, 5, 6, 7], "§3.1 range")
	_assert_indices("0-10:2", 20, [0, 2, 4, 6, 8, 10], "§3.1 stride 2")
	_assert_indices("0-10:3", 20, [0, 3, 6, 9], "§3.1 stride 3")
	_assert_indices("*", 20, range(20), "§3.1 all")
	_assert_indices("*:3", 20, [0, 3, 6, 9, 12, 15, 18], "§3.1 *:3")
	_assert_indices("*:2", 20, [0, 2, 4, 6, 8, 10, 12, 14, 16, 18], "§3.1 *:2")
	var except := []
	for i in range(20):
		if i < 5 or i > 10:
			except.append(i)
	_assert_indices("!5-10", 20, except, "§3.1 !5-10")


func test_pat_32_take_skip() -> void:
	_assert_indices("0-19:2,5", 20, [0, 1, 5, 6, 10, 11, 15, 16], "§3.2 take 2 period 5")
	_assert_indices("0-19:1,3", 20, [0, 3, 6, 9, 12, 15, 18], "§3.2 take 1 period 3")
	_assert_indices("0-19:3,4", 20, [0, 1, 2, 4, 5, 6, 8, 9, 10, 12, 13, 14, 16, 17, 18], "§3.2 take 3 period 4")


func test_pat_33_multi_and_practical() -> void:
	_assert_indices("0-5, 10-15", 20, [0, 1, 2, 3, 4, 5, 10, 11, 12, 13, 14, 15], "§3.3 two ranges")
	_assert_indices("0-5, 10-15, 20", 25, [0, 1, 2, 3, 4, 5, 10, 11, 12, 13, 14, 15, 20], "§3.3 plus exact")
	_assert_indices("1-999:2", 10, [1, 3, 5, 7, 9], "§3.5 odds")
	_assert_indices("1-999:1,3", 16, [1, 4, 7, 10, 13], "§3.5 interleaved Y")
	_assert_indices("0-20, !10-12", 21, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 13, 14, 15, 16, 17, 18, 19, 20], "§6.2 exclusion")
	_assert_indices("0-3, 10-13, 20", 25, [0, 1, 2, 3, 10, 11, 12, 13, 20], "§6.2 multi")


# ─── §4 expansion ────────────────────────────────────────────────────────────

func test_pat_4_expansion() -> void:
	_assert_expand("ch[1-4]", PackedStringArray(["ch1", "ch2", "ch3", "ch4"]), "§4.1 numeric")
	_assert_expand("ch[0-8:2]", PackedStringArray(["ch0", "ch2", "ch4", "ch6", "ch8"]), "§4.1 stride")
	_assert_expand("blend[1,3,5]", PackedStringArray(["blend1", "blend3", "blend5"]), "§4.1 list")
	_assert_expand("[rgb]_out", PackedStringArray(["r_out", "g_out", "b_out"]), "§4.2 alpha")
	_assert_expand("[tr][xyz]", PackedStringArray(["tx", "ty", "tz", "rx", "ry", "rz"]), "§4.3 cartesian")
	_assert_expand("[ab][12]", PackedStringArray(["a1", "a2", "b1", "b2"]), "§4.3 ab12")
	_assert_expand("ch[1-2] pos[xyz]", PackedStringArray(["ch1", "ch2", "posx", "posy", "posz"]), "§4.4 tokens")


# ─── §5 / §6 rename ──────────────────────────────────────────────────────────

func test_pat_5_rename() -> void:
	GNTestAssert.assert_eq(GNPattern.rename("foo_old", "*_old", "*(0)_new"), "foo_new", "§5.2 foo")
	GNTestAssert.assert_eq(GNPattern.rename("bar_baz_old", "*_old", "*(0)_new"), "bar_baz_new", "§5.2 bar_baz")
	GNTestAssert.assert_eq(GNPattern.rename("left_monitor", "*_*", "*(1)_*(0)"), "monitor_left", "§5.2 swap")
	GNTestAssert.assert_eq(GNPattern.rename("foo_bar", "*_*", "*(1).*(0)"), "bar.foo", "§5.2 dot")
	GNTestAssert.assert_eq(GNPattern.rename("tx", "?x", "?(0)y"), "ty", "§5.2 tx")
	GNTestAssert.assert_eq(GNPattern.rename("ab_hello", "??_*", "*(0)_?(1)?(0)"), "hello_ba", "§5.2 reverse pair")
	GNTestAssert.assert_eq(GNPattern.rename("bar", "*_old", "*(0)_new"), "bar", "§6.4 passthrough")
	GNTestAssert.assert_eq(GNPattern.rename("foo_old", "*_old", "*_new"), "foo_new", "§5.3 bare star")
	GNTestAssert.assert_eq(GNPattern.rename("old_position", "old_*", "new_*(0)"), "new_position", "§5.5 prefix")
	GNTestAssert.assert_eq(GNPattern.rename("left_side_monitor", "*_side_*", "*(1)_floor_*(0)"), "monitor_floor_left", "§5.5 two-part")


func test_pat_6_api_snippets() -> void:
	GNTestAssert.assert_true(GNPattern.matches("tx", "t?"), "§6.1 t?")
	GNTestAssert.assert_true(GNPattern.matches("blend2", "blend*"), "§6.1 blend")
	GNTestAssert.assert_true(GNPattern.matches("hello", "[a-z]*"), "§6.1 class")
	GNTestAssert.assert_true(GNPattern.matches_any("tx", "t*, !tz"), "§6.1 include")
	GNTestAssert.assert_false(GNPattern.matches_any("tz", "t*, !tz"), "§6.1 excluded")
	var split: Dictionary = GNPattern.split_patterns("tx, ty, !tz, rz")
	GNTestAssert.assert_eq(" ".join(split["include"]), "tx ty rz", "§6.5 include")
	GNTestAssert.assert_eq(" ".join(split["exclude"]), "tz", "§6.5 exclude")
	var only_ex: Dictionary = GNPattern.split_patterns("!temp*")
	GNTestAssert.assert_eq(" ".join(only_ex["include"]), "*", "§6.5 implied star")
	GNTestAssert.assert_eq(" ".join(only_ex["exclude"]), "temp*", "§6.5 temp exclude")

	var names := PackedStringArray(["tx", "ty", "tz", "scale"])
	var renamed: Dictionary = GNPattern.rename_batch(names, "t?", "?(0)_translate")
	GNTestAssert.assert_eq(renamed.get("tx", ""), "x_translate", "§6.4 tx")
	GNTestAssert.assert_eq(renamed.get("ty", ""), "y_translate", "§6.4 ty")
	GNTestAssert.assert_false(renamed.has("scale"), "§6.4 scale unmatched")

	var chans := PackedStringArray(["a", "b", "c", "d"])
	var numbered: Dictionary = GNPattern.rename_batch(chans, "*", "out[1-4]")
	GNTestAssert.assert_eq(numbered.get("a", ""), "out1", "§6.4 expand a")
	GNTestAssert.assert_eq(numbered.get("d", ""), "out4", "§6.4 expand d")
