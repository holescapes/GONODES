extends Node
## Unit tests for GNParamRow string control selection.
##
## Non-code STRING parameters must use a one-line LineEdit (IP, OSC, labels, etc.).
## Code parameters keep the multi-line TextEdit preview inside a VBox wrapper.


func test_non_code_string_param_uses_line_edit() -> void:
	var node := DmxOutCHOP.new()
	node.initialize("dmx1")
	var p: GNParameter = node.parameters["ip"]
	var row := GNParamRow.new()
	add_child(row)
	row.setup(p, node)

	GNTestAssert.assert_true(row._control is LineEdit,
		"Non-code STRING param control should be LineEdit")
	var line_edit := row._control as LineEdit
	GNTestAssert.assert_eq(line_edit.custom_minimum_size.y, 28,
		"LineEdit should be one line tall (~28px)")
	GNTestAssert.assert_true(line_edit.editable,
		"Editable string LineEdit should accept input")

	row.queue_free()
	node.queue_free()


func test_read_only_non_code_string_uses_line_edit() -> void:
	var p := GNParameter.create_string("host", "127.0.0.1", "Host", "Read-only host")
	p.read_only = true
	var node := DmxOutCHOP.new()
	node.initialize("dmx2")
	var row := GNParamRow.new()
	add_child(row)
	row.setup(p, node)

	GNTestAssert.assert_true(row._control is LineEdit,
		"Read-only non-code STRING param should use LineEdit, not TextEdit")
	var line_edit := row._control as LineEdit
	GNTestAssert.assert_false(line_edit.editable,
		"Read-only LineEdit should not be editable")
	GNTestAssert.assert_eq(line_edit.custom_minimum_size.y, 28,
		"Read-only LineEdit should stay one line tall")

	row.queue_free()
	node.queue_free()


func test_code_string_param_uses_text_edit_preview() -> void:
	var node := GDScriptSCRIPT.new()
	node.initialize("scr1")
	var p: GNParameter = node.parameters["code"]
	var row := GNParamRow.new()
	add_child(row)
	row.setup(p, node)

	GNTestAssert.assert_true(row._control is VBoxContainer,
		"Code STRING param should wrap preview in VBoxContainer")
	GNTestAssert.assert_not_null(row._code_edit,
		"Code param should expose preview TextEdit via _code_edit")
	GNTestAssert.assert_false(row._code_edit.editable,
		"Code preview TextEdit should be read-only")

	row.queue_free()
	node.queue_free()


func test_string_line_edit_submitted_commits_value() -> void:
	var node := DmxOutCHOP.new()
	node.initialize("dmx3")
	var p: GNParameter = node.parameters["ip"]
	var row := GNParamRow.new()
	add_child(row)
	row.setup(p, node)
	var line_edit := row._control as LineEdit
	line_edit.text = "192.168.0.10"
	line_edit.text_submitted.emit("192.168.0.10")

	GNTestAssert.assert_eq(str(p.value), "192.168.0.10",
		"Enter (text_submitted) should commit string value immediately")

	row.queue_free()
	node.queue_free()


func test_file_dropdown_popup_height_is_capped() -> void:
	var p := GNParameter.create_folder("folder", "", "Folder", "Folder picker")
	var node := DmxOutCHOP.new()
	node.initialize("dmx_file")
	var row := GNParamRow.new()
	add_child(row)
	row.setup(p, node)

	var hbox := row._control as HBoxContainer
	GNTestAssert.assert_not_null(hbox, "FILE param uses an HBox")
	var option := hbox.get_child(0) as OptionButton
	GNTestAssert.assert_not_null(option, "FILE param starts with an OptionButton")
	GNTestAssert.assert_eq(option.get_popup().max_size.y, GNParamRow.FILE_DROPDOWN_MAX_HEIGHT,
		"file list height is capped so a long scan scrolls")
	GNTestAssert.assert_eq(option.get_popup().max_size.x, 0,
		"file list width stays uncapped")

	row.queue_free()
	node.queue_free()


func test_enum_dropdown_does_not_adopt_long_item_width() -> void:
	var long_name := "Speakers (Realtek High Definition Audio Device)"
	var p := GNParameter.create_enum("device",
		PackedStringArray(["Default", long_name]), 1, "Device", "Output device")
	var node := DmxOutCHOP.new()
	node.initialize("dmx_enum")
	var row := GNParamRow.new()
	add_child(row)
	row.setup(p, node)

	var option := row._control as OptionButton
	GNTestAssert.assert_not_null(option, "ENUM param is an OptionButton")
	GNTestAssert.assert_false(option.fit_to_longest_item,
		"enum list does not set the button width")
	GNTestAssert.assert_true(option.clip_text, "long enum text clips")
	GNTestAssert.assert_true(option.get_combined_minimum_size().x < 220.0,
		"a long device name does not set the side panel minimum width")

	row.queue_free()
	node.queue_free()
