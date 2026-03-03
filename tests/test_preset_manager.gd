extends Node
## Unit tests for GNParamPresetManager — clipboard copy/paste and type gating.
##
## Tests cover:
##   - Copy / paste between same operator type
##   - Paste rejection for mismatched operator type
##   - Clipboard state queries (has_clipboard, can_paste, clipboard_operator_type)
##   - Value restoration after paste
##   - Reset to defaults
##
## NOTE: File-based save/load/delete tests are skipped because they depend on
## the user:// filesystem which may not be writable in headless CI.  These
## should be tested manually or in an integration test.

# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func before_each() -> void:
	# Clear the static clipboard between tests by copying from a null node
	# (copy_params with null is a no-op, so just overwrite directly via copy)
	GNParamPresetManager._clipboard.clear()


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _make_constant_chop(id: String) -> GNNode:
	var node := ConstantCHOP.new()
	node.initialize(id)
	add_child(node)
	return node


func _make_null_chop(id: String) -> GNNode:
	var node := NullCHOP.new()
	node.initialize(id)
	add_child(node)
	return node


# ═══════════════════════════════════════════════════════════════════════════════
# Clipboard Empty State
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_clipboard() -> void:
	GNTestAssert.assert_false(GNParamPresetManager.has_clipboard(), "initially empty")
	GNTestAssert.assert_eq(GNParamPresetManager.clipboard_operator_type(), "", "no type")


func test_cannot_paste_with_empty_clipboard() -> void:
	var node := _make_constant_chop("c1")
	GNTestAssert.assert_false(GNParamPresetManager.can_paste(node), "can't paste empty")
	var result := GNParamPresetManager.paste_params(node)
	GNTestAssert.assert_eq(result, 0, "paste returns 0")
	node.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Copy & Paste — Same Type
# ═══════════════════════════════════════════════════════════════════════════════

func test_copy_populates_clipboard() -> void:
	var node := _make_constant_chop("c1")
	GNParamPresetManager.copy_params(node)
	GNTestAssert.assert_true(GNParamPresetManager.has_clipboard(), "clipboard populated")
	GNTestAssert.assert_eq(GNParamPresetManager.clipboard_operator_type(), "ConstantCHOP", "type")
	node.queue_free()


func test_can_paste_same_type() -> void:
	var source := _make_constant_chop("src")
	var target := _make_constant_chop("tgt")
	GNParamPresetManager.copy_params(source)
	GNTestAssert.assert_true(GNParamPresetManager.can_paste(target), "same type = can paste")
	source.queue_free()
	target.queue_free()


func test_paste_restores_values() -> void:
	var source := _make_constant_chop("src")
	source.set_param_value("name0", "custom_ch")
	source.set_param_value("value0", 42.0)
	GNParamPresetManager.copy_params(source)

	var target := _make_constant_chop("tgt")
	GNTestAssert.assert_eq(target.get_param_value("name0"), "chan1", "default before paste")
	var applied := GNParamPresetManager.paste_params(target)
	GNTestAssert.assert_gt(applied, 0, "some params applied")
	GNTestAssert.assert_eq(target.get_param_value("name0"), "custom_ch", "name restored")
	GNTestAssert.assert_approx(target.get_param_value("value0"), 42.0, 0.001, "value restored")
	source.queue_free()
	target.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Paste — Type Mismatch Rejection
# ═══════════════════════════════════════════════════════════════════════════════

func test_cannot_paste_different_type() -> void:
	var source := _make_constant_chop("src")
	GNParamPresetManager.copy_params(source)

	var target := _make_null_chop("tgt")
	GNTestAssert.assert_false(GNParamPresetManager.can_paste(target),
		"NullCHOP ≠ ConstantCHOP")
	var applied := GNParamPresetManager.paste_params(target)
	GNTestAssert.assert_eq(applied, 0, "no params applied for wrong type")
	source.queue_free()
	target.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Copy Overwrites Previous Clipboard
# ═══════════════════════════════════════════════════════════════════════════════

func test_copy_overwrites_clipboard() -> void:
	var n1 := _make_constant_chop("c1")
	n1.set_param_value("value0", 10.0)
	GNParamPresetManager.copy_params(n1)

	var n2 := _make_constant_chop("c2")
	n2.set_param_value("value0", 99.0)
	GNParamPresetManager.copy_params(n2)

	var target := _make_constant_chop("tgt")
	GNParamPresetManager.paste_params(target)
	# Should have n2's value, not n1's
	GNTestAssert.assert_approx(target.get_param_value("value0"), 99.0, 0.001,
		"latest copy should win")
	n1.queue_free()
	n2.queue_free()
	target.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Null Safety
# ═══════════════════════════════════════════════════════════════════════════════

func test_copy_null_node_is_safe() -> void:
	GNParamPresetManager.copy_params(null)
	GNTestAssert.assert_false(GNParamPresetManager.has_clipboard(), "still empty after null copy")


func test_can_paste_null_node() -> void:
	GNTestAssert.assert_false(GNParamPresetManager.can_paste(null), "null → false")


func test_paste_null_node() -> void:
	var result := GNParamPresetManager.paste_params(null)
	GNTestAssert.assert_eq(result, 0, "null → 0")


# ═══════════════════════════════════════════════════════════════════════════════
# Reset to Defaults
# ═══════════════════════════════════════════════════════════════════════════════

func test_reset_to_defaults() -> void:
	var node := _make_constant_chop("c1")
	# Modify params away from defaults
	node.set_param_value("name0", "modified_name")
	node.set_param_value("value0", 999.0)
	GNTestAssert.assert_eq(node.get_param_value("name0"), "modified_name", "modified before reset")

	var reset_count := GNParamPresetManager.reset_to_defaults(node)
	GNTestAssert.assert_gt(reset_count, 0, "some params were reset")
	GNTestAssert.assert_eq(node.get_param_value("name0"), "chan1", "name0 back to default")
	GNTestAssert.assert_approx(node.get_param_value("value0"), 0.0, 0.001, "value0 back to default")
	node.queue_free()
