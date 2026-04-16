class_name LineEditUI
extends GNUiBase
## Single-line text input widget for PanelTOP.
##
## Outputs widget_state: {"length": <int>, "submitted": 0 or 1}
## The typed text is available as a DAT output string via PanelTOP's
## secondary channels, or can be read directly from the widget.

var _line_edit: LineEdit = null
var _submitted: float = 0.0
var _current_text: String = ""


func _init() -> void:
	node_type = "line_edit"


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("placeholder", "Type here...", "Placeholder", "Placeholder text"))
	add_parameter(GNParameter.create_string("default_text", "", "Default", "Initial text content"))
	add_parameter(GNParameter.create_int("max_length", 0, 0, 1024, "Max Length", "Max characters (0 = unlimited)"))
	add_parameter(GNParameter.create_bool("editable", true, "Editable", "Allow text input"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(200, 32), "Min Size", "Minimum widget size"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_line_edit()

	_line_edit.placeholder_text = get_param_value("placeholder")
	_line_edit.max_length = get_param_value("max_length")
	_line_edit.editable = get_param_value("editable")
	var ms: Vector2i = get_param_value("min_size")
	_line_edit.custom_minimum_size = Vector2(ms.x, ms.y)

	_current_text = _line_edit.text

	widget_state = {
		"length": float(_current_text.length()),
		"submitted": _submitted,
		"text": _current_text,
	}
	_submitted = 0.0
	return null


func _ensure_line_edit() -> void:
	if _line_edit != null:
		return
	_line_edit = LineEdit.new()
	_line_edit.name = id + "_lineedit"
	_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line_edit.text = widget_state.get("text", get_param_value("default_text"))
	_line_edit.text_submitted.connect(_on_text_submitted)
	_line_edit.text_changed.connect(_on_text_changed)
	_control_node = _line_edit


func get_text() -> String:
	return _current_text


func _on_text_submitted(_text: String) -> void:
	_submitted = 1.0
	_current_text = _text
	widget_state["submitted"] = 1.0
	widget_state["length"] = float(_text.length())
	mark_dirty()


func _on_text_changed(new_text: String) -> void:
	_current_text = new_text
	widget_state["length"] = float(new_text.length())
	mark_dirty()


func destroy_control_node() -> void:
	if _line_edit != null:
		if _line_edit.text_submitted.is_connected(_on_text_submitted):
			_line_edit.text_submitted.disconnect(_on_text_submitted)
		if _line_edit.text_changed.is_connected(_on_text_changed):
			_line_edit.text_changed.disconnect(_on_text_changed)
	_line_edit = null
	_submitted = 0.0
	super.destroy_control_node()
