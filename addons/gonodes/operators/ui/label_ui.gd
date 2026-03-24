class_name LabelUI
extends GNUiBase
## Text label widget for PanelTOP.
##
## Outputs widget_state: {} (read-only display, no interactive state).
## Accepts an optional CHOP input — displays its channel values as text.

var _label: Label = null


func _init() -> void:
	node_type = "label"


func _init_ports() -> void:
	add_input("chop", GNFamily.Type.CHOP, false, "CHOP values to display")
	add_output("out", GNFamily.Type.UI, "Widget output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("text", "Label", "Text", "Static label text"))
	add_parameter(GNParameter.create_int("font_size", 16, 8, 128, "Font Size", "Text size in pixels"))
	add_parameter(GNParameter.create_color("font_color", Color.WHITE, "Color", "Text color"))
	add_parameter(GNParameter.create_enum("h_align",
		PackedStringArray(["Left", "Center", "Right"]), 1, "H Align", "Horizontal alignment"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(120, 24), "Min Size", "Minimum label size"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_label()

	var text: String = get_param_value("text")
	var font_size: int = get_param_value("font_size")
	var font_color: Color = get_param_value("font_color")
	var h_align: int = get_param_value("h_align")
	var ms: Vector2i = get_param_value("min_size")

	# If CHOP input is connected, append channel values
	if inputs.size() > 0 and inputs[0] is GNChannelData:
		var chop: GNChannelData = inputs[0] as GNChannelData
		var lines: PackedStringArray = [text]
		for ch_name in chop.get_channel_names():
			lines.append("%s: %.3f" % [ch_name, chop.get_value(ch_name)])
		text = "\n".join(lines)

	_label.text = text
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", font_color)
	_label.custom_minimum_size = Vector2(ms.x, ms.y)

	match h_align:
		0: _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		1: _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		2: _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	widget_state = {}

	return null


func _ensure_label() -> void:
	if _label != null:
		return
	_label = Label.new()
	_label.name = id + "_label"
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_control_node = _label


func destroy_control_node() -> void:
	_label = null
	super.destroy_control_node()
