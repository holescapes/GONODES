class_name TextEditUI
extends GNUiBase
## Multi-line text editor widget for PanelTOP.
##
## Accepts an optional DAT input to pre-populate text content.
## Outputs widget_state: {"lines": <int>, "length": <int>}

var _text_edit: TextEdit = null
var _current_text: String = ""


func _init() -> void:
	node_type = "textedit"
	node_description = "Multi-line text editor. Optional DAT input for initial content."


func _init_ports() -> void:
	add_input("dat", GNFamily.Type.DAT, false, "DAT text to pre-populate")
	add_output("out", GNFamily.Type.UI, "Widget output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("placeholder", "Enter text...", "Placeholder", "Placeholder text"))
	add_parameter(GNParameter.create_bool("editable", true, "Editable", "Allow text editing"))
	add_parameter(GNParameter.create_bool("wrap_mode", true, "Word Wrap", "Enable word wrapping"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(250, 150), "Min Size", "Minimum editor size"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_text_edit()

	# DAT input → set text content (only if user hasn't edited)
	if inputs.size() > 0 and inputs[0] is GNTableData:
		var dat: GNTableData = inputs[0] as GNTableData
		var dat_text: String = dat.get_text() if dat.has_method("get_text") else ""
		if dat_text.length() > 0 and not _text_edit.has_focus():
			_text_edit.text = dat_text

	_text_edit.placeholder_text = get_param_value("placeholder")
	_text_edit.editable = get_param_value("editable")
	_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY if get_param_value("wrap_mode") else TextEdit.LINE_WRAPPING_NONE
	var ms: Vector2i = get_param_value("min_size")
	_text_edit.custom_minimum_size = Vector2(ms.x, ms.y)

	_current_text = _text_edit.text

	widget_state = {
		"lines": float(_text_edit.get_line_count()),
		"length": float(_current_text.length()),
	}
	return null


func get_text() -> String:
	return _current_text


func _ensure_text_edit() -> void:
	if _text_edit != null:
		return
	_text_edit = TextEdit.new()
	_text_edit.name = id + "_textedit"
	_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_edit.text_changed.connect(_on_text_changed)
	_control_node = _text_edit


func _on_text_changed() -> void:
	_current_text = _text_edit.text
	widget_state["lines"] = float(_text_edit.get_line_count())
	widget_state["length"] = float(_current_text.length())
	mark_dirty()


func destroy_control_node() -> void:
	if _text_edit != null and _text_edit.text_changed.is_connected(_on_text_changed):
		_text_edit.text_changed.disconnect(_on_text_changed)
	_text_edit = null
	super.destroy_control_node()
