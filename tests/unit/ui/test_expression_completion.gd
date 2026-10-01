extends Node
## Unit tests for shared expression autocomplete catalog.


func _find_entry_by_name(entries: Array[Dictionary], name: String) -> Dictionary:
	for entry in entries:
		if GNExpressionEditor.completion_entry_name(entry) == name:
			return entry
	return {}


func test_general_completion_includes_chop_and_sin() -> void:
	var entries := GNExpressionEditor.get_general_completion_entries()
	var chop_entry := _find_entry_by_name(entries, "chop")
	var sin_entry := _find_entry_by_name(entries, "sin")

	GNTestAssert.assert_false(chop_entry.is_empty(),
		"Shared general list should include chop")
	GNTestAssert.assert_false(sin_entry.is_empty(),
		"Shared general list should include sin")
	GNTestAssert.assert_eq(chop_entry.get("insert", ""), "chop(\"",
		"chop insert text should open a quoted call")
	GNTestAssert.assert_eq(sin_entry.get("insert", ""), "sin(",
		"sin insert text should open a function call")


func test_general_completion_prefix_ch_matches_chop_not_sin() -> void:
	var filtered := GNExpressionEditor.filter_general_completions("ch")

	GNTestAssert.assert_gt(filtered.size(), 0,
		"Prefix 'ch' should match at least one completion")

	var names: Array[String] = []
	for entry in filtered:
		var entry_name := GNExpressionEditor.completion_entry_name(entry)
		names.append(entry_name)
		GNTestAssert.assert_true(entry_name.to_lower().begins_with("ch"),
			"Filtered entry '%s' should begin with 'ch'" % entry_name)

	GNTestAssert.assert_true(names.has("chop"),
		"Prefix 'ch' should match chop")
	GNTestAssert.assert_false(names.has("sin"),
		"Prefix 'ch' should not match sin")


func test_general_completion_prefix_c_matches_more_than_ch() -> void:
	var c_filtered := GNExpressionEditor.filter_general_completions("c")
	var ch_filtered := GNExpressionEditor.filter_general_completions("ch")

	GNTestAssert.assert_gt(c_filtered.size(), ch_filtered.size(),
		"Prefix 'c' should match more entries than 'ch'")

	var ch_names: Array[String] = []
	for entry in ch_filtered:
		ch_names.append(GNExpressionEditor.completion_entry_name(entry))

	GNTestAssert.assert_true(ch_names.has("chop"),
		"Prefix 'ch' should still match chop")
	GNTestAssert.assert_false(ch_names.has("sin"),
		"Prefix 'ch' should not match sin")


func test_line_edit_caret_text_offset_grows_with_prefix() -> void:
	var edit := LineEdit.new()
	add_child(edit)
	edit.text = "hello"
	edit.caret_column = 0
	var x_empty := GNParamRow.line_edit_caret_text_offset_x(edit)
	edit.caret_column = edit.text.length()
	var x_full := GNParamRow.line_edit_caret_text_offset_x(edit)

	GNTestAssert.assert_gt(x_full, x_empty,
		"Caret text offset should grow as the typed prefix lengthens")

	edit.queue_free()


func test_expr_autocomplete_panel_height_single_row() -> void:
	var row_h := 32.0
	var h := GNParamRow.compute_expr_autocomplete_panel_height(row_h, 1)

	GNTestAssert.assert_eq(h, row_h + GNParamRow.EXPR_AUTOCOMPLETE_LIST_VERTICAL_INSET + GNParamRow.EXPR_AUTOCOMPLETE_SCROLL_PAD,
		"Single-row panel must fit row height plus insets and scroll pad")
	GNTestAssert.assert_true(h <= GNParamRow.EXPR_AUTOCOMPLETE_LIST_MAX_HEIGHT,
		"Panel height must respect LIST_MAX_HEIGHT cap")


func test_expr_autocomplete_panel_height_caps_many_rows() -> void:
	var row_h := 32.0
	var few := GNParamRow.compute_expr_autocomplete_panel_height(row_h, 3)
	var many := GNParamRow.compute_expr_autocomplete_panel_height(row_h, 10)

	GNTestAssert.assert_eq(few, row_h * 3.0 + GNParamRow.EXPR_AUTOCOMPLETE_LIST_VERTICAL_INSET + GNParamRow.EXPR_AUTOCOMPLETE_SCROLL_PAD,
		"Few rows should use full content height without capping")
	GNTestAssert.assert_eq(many, GNParamRow.EXPR_AUTOCOMPLETE_LIST_MAX_HEIGHT,
		"Many rows should cap at LIST_MAX_HEIGHT")


func test_expr_autocomplete_suggestion_widget_is_non_focusable() -> void:
	var widget := GNParamRow.make_expr_autocomplete_suggestion_widget()

	GNTestAssert.assert_eq(widget.focus_mode, Control.FOCUS_NONE,
		"Suggestion widget must stay out of the focus chain")
	GNTestAssert.assert_eq(widget.get_class(), "Panel",
		"Suggestion widget must be an in-window Panel, not a Window")

	var list := widget.get_node("List") as ItemList
	GNTestAssert.assert_not_null(list,
		"Suggestion widget should contain an ItemList")
	GNTestAssert.assert_eq(list.focus_mode, Control.FOCUS_NONE,
		"ItemList must not grab keyboard focus")

	widget.queue_free()
