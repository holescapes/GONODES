class_name RichTextLabelUI
extends GNUiBase
## Rich text label widget for PanelTOP.
##
## Displays BBCode-formatted text. Accepts an optional DAT input for content.
## Outputs widget_state: {} (read-only display).

var _rtl: RichTextLabel = null


func _init() -> void:
	node_type = "richtextlabel"
	node_description = "BBCode rich text label. Optional DAT input for content."


func _init_ports() -> void:
	add_input("dat", GNFamily.Type.DAT, false, "DAT text/BBCode content")
	add_output("out", GNFamily.Type.UI, "Widget output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("text", "[b]Hello[/b] World", "Text", "BBCode text content"))
	add_parameter(GNParameter.create_bool("bbcode", true, "BBCode", "Enable BBCode parsing"))
	add_parameter(GNParameter.create_int("font_size", 16, 8, 128, "Font Size", "Text size in pixels"))
	add_parameter(GNParameter.create_bool("fit_content", true, "Fit Content", "Auto-resize to fit text"))
	add_parameter(GNParameter.create_bool("scroll_active", false, "Scrollable", "Enable scroll bars"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(200, 40), "Min Size", "Minimum widget size"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_rtl()

	var text: String = get_param_value("text")

	# DAT input overrides parameter text
	if inputs.size() > 0 and inputs[0] is GNTableData:
		var dat: GNTableData = inputs[0] as GNTableData
		if dat.is_table:
			# Convert table to formatted text
			var lines := PackedStringArray()
			for r in range(dat.num_rows()):
				var row_parts := PackedStringArray()
				for c in range(dat.num_cols()):
					row_parts.append(dat.cell(r, c))
				lines.append("  ".join(row_parts))
			text = "\n".join(lines)
		else:
			text = dat.text

	_rtl.bbcode_enabled = get_param_value("bbcode")
	_rtl.text = text
	_rtl.add_theme_font_size_override("normal_font_size", get_param_value("font_size"))
	_rtl.fit_content = get_param_value("fit_content")
	_rtl.scroll_active = get_param_value("scroll_active")
	var ms: Vector2i = get_param_value("min_size")
	_rtl.custom_minimum_size = Vector2(ms.x, ms.y)

	widget_state = {}
	return null


func _ensure_rtl() -> void:
	if _rtl != null:
		return
	_rtl = RichTextLabel.new()
	_rtl.name = id + "_richtextlabel"
	_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rtl.bbcode_enabled = true
	_rtl.fit_content = true
	_control_node = _rtl
