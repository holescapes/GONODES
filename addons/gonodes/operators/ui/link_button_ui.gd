class_name LinkButtonUI
extends GNUiBase
## Link-styled button widget for PanelTOP.
##
## Displays a clickable text link (underlined button).
## Outputs widget_state: {"press": 0 or 1} (impulse)

var _link_btn: LinkButton = null


func _init() -> void:
	node_type = "link_button"


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("text", "Click here", "Text", "Link text"))
	add_parameter(GNParameter.create_enum("underline",
		PackedStringArray(["Always", "On Hover", "Never"]), 0,
		"Underline", "Underline behavior"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(80, 24), "Min Size", "Minimum widget size"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_link_btn()

	_link_btn.text = get_param_value("text")
	var underline: int = get_param_value("underline")
	match underline:
		0: _link_btn.underline = LinkButton.UNDERLINE_MODE_ALWAYS
		1: _link_btn.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
		2: _link_btn.underline = LinkButton.UNDERLINE_MODE_NEVER
	var ms: Vector2i = get_param_value("min_size")
	_link_btn.custom_minimum_size = Vector2(ms.x, ms.y)

	widget_state = {"press": 0.0}
	return null


func _ensure_link_btn() -> void:
	if _link_btn != null:
		return
	_link_btn = LinkButton.new()
	_link_btn.name = id + "_linkbtn"
	_link_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_link_btn.pressed.connect(_on_pressed)
	_control_node = _link_btn


func _on_pressed() -> void:
	widget_state["press"] = 1.0
	mark_dirty()


func destroy_control_node() -> void:
	if _link_btn != null and _link_btn.pressed.is_connected(_on_pressed):
		_link_btn.pressed.disconnect(_on_pressed)
	_link_btn = null
	super.destroy_control_node()
