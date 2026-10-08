class_name RichTextTOP
extends GNTopBase
## Renders BBCode rich text onto a texture via Godot's RichTextLabel.
## Multiple styles in one string (bold, color, size, fonts, images, etc.).


var _rtl: RichTextLabel = null
var _bg: ColorRect = null
var _loaded_font: Font = null
var _loaded_font_path: String = ""


func _init() -> void:
	node_type = "richtext"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Rendered rich-text texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("text",
		"[b]Hello[/b] [color=#88ccff]GONODES[/color]",
		"Text",
		"BBCode (or plain) text content. Supports multiple styles in one string.",
		true))
	add_parameter(GNParameter.create_bool("bbcode", true, "BBCode",
		"Parse BBCode tags ([b], [color], [font_size], …). Off = plain text."))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 256),
		"Resolution", "Output texture resolution in pixels"))
	add_parameter(GNParameter.create_file("font_file", "Path to the font file",
		PackedStringArray(["*.ttf", "*.otf", "*.woff", "*.woff2", "*.tres", "*.res"]),
		"", "Default/normal font (project://, res://, or absolute). Empty = theme default."))
	add_parameter(GNParameter.create_int("font_size", 48, 8, 256, "Font Size",
		"Default font size in pixels (BBCode [font_size=N] can override spans)"))
	add_parameter(GNParameter.create_color("font_color", Color.WHITE, "Font Color",
		"Default text color (BBCode [color=…] can override spans)"))
	add_parameter(GNParameter.create_color("bg_color", Color.BLACK, "Bg Color",
		"Background color (alpha 0 for transparent overlays)"))
	add_parameter(GNParameter.create_enum("align_h",
		PackedStringArray(["Left", "Center", "Right"]), 1, "",
		"Horizontal text alignment"))
	add_parameter(GNParameter.create_enum("align_v",
		PackedStringArray(["Top", "Center", "Bottom"]), 1, "",
		"Vertical text alignment"))
	add_parameter(GNParameter.create_bool("word_wrap", true, "Word Wrap",
		"Wrap text at texture edges"))
	add_parameter(GNParameter.create_int("outline_size", 0, 0, 64, "Outline Size",
		"Default glyph outline width in pixels (0 = off)"))
	add_parameter(GNParameter.create_color("outline_color", Color(0, 0, 0, 1),
		"Outline Color", "Default outline color"))
	add_parameter(GNParameter.create_bool("shadow", false, "Shadow",
		"Enable drop shadow behind glyphs"))
	add_parameter(GNParameter.create_color("shadow_color", Color(0, 0, 0, 0.6),
		"Shadow Color", "Drop shadow color"))
	add_parameter(GNParameter.create_vector2i("shadow_offset", Vector2i(2, 2),
		"Shadow Offset", "Drop shadow offset in pixels"))
	add_parameter(GNParameter.create_vector2i("margin", Vector2i(0, 0), "Margin",
		"Inset from the texture edges in pixels (left/top; also right/bottom)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_setup_viewport()

	var txt: String = get_param_value("text")
	var use_bbcode: bool = bool(get_param_value("bbcode"))
	var res: Vector2i = get_param_value("resolution")
	var font_path: String = get_param_value("font_file")
	var fsize: int = get_param_value("font_size")
	var fcol: Color = get_param_value("font_color")
	var bgcol: Color = get_param_value("bg_color")
	var ah: int = get_param_value("align_h")
	var av: int = get_param_value("align_v")
	var wrap: bool = get_param_value("word_wrap")
	var outline_sz: int = int(get_param_value("outline_size"))
	var outline_col: Color = get_param_value("outline_color")
	var use_shadow: bool = bool(get_param_value("shadow"))
	var shadow_col: Color = get_param_value("shadow_color")
	var shadow_off: Vector2i = get_param_value("shadow_offset")
	var margin: Vector2i = get_param_value("margin")

	_ensure_viewport_size(res)
	_bg.color = bgcol
	_apply_font(font_path)

	_rtl.bbcode_enabled = use_bbcode
	_rtl.text = txt
	_rtl.scroll_active = false
	_rtl.fit_content = false
	_rtl.selection_enabled = false
	_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_rtl.add_theme_font_size_override("normal_font_size", fsize)
	_rtl.add_theme_color_override("default_color", fcol)

	if outline_sz > 0:
		_rtl.add_theme_constant_override("outline_size", outline_sz)
		_rtl.add_theme_color_override("font_outline_color", outline_col)
	else:
		_rtl.remove_theme_constant_override("outline_size")
		_rtl.remove_theme_color_override("font_outline_color")

	if use_shadow:
		_rtl.add_theme_color_override("font_shadow_color", shadow_col)
		_rtl.add_theme_constant_override("shadow_offset_x", shadow_off.x)
		_rtl.add_theme_constant_override("shadow_offset_y", shadow_off.y)
	else:
		_rtl.remove_theme_color_override("font_shadow_color")
		_rtl.remove_theme_constant_override("shadow_offset_x")
		_rtl.remove_theme_constant_override("shadow_offset_y")

	match ah:
		0:
			_rtl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		1:
			_rtl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		2:
			_rtl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	match av:
		0:
			_rtl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		1:
			_rtl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		2:
			_rtl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	_rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF

	var mx := maxi(margin.x, 0)
	var my := maxi(margin.y, 0)
	_rtl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rtl.offset_left = float(mx)
	_rtl.offset_top = float(my)
	_rtl.offset_right = float(-mx)
	_rtl.offset_bottom = float(-my)

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _setup_viewport() -> void:
	if _viewport != null:
		return

	# Transparent so overlays (bg alpha 0) composite correctly via Over.
	_ensure_viewport(get_param_value("resolution"), true)

	_bg = ColorRect.new()
	_bg.name = "BG"
	_bg.color = Color.BLACK
	_viewport.add_child(_bg)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_rtl = RichTextLabel.new()
	_rtl.name = "RichText"
	_rtl.bbcode_enabled = true
	_rtl.scroll_active = false
	_rtl.fit_content = false
	_rtl.selection_enabled = false
	_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rtl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rtl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_viewport.add_child(_rtl)
	_rtl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _apply_font(font_path: String) -> void:
	if font_path == _loaded_font_path:
		return
	_loaded_font_path = font_path
	if font_path.is_empty():
		_loaded_font = null
		_rtl.remove_theme_font_override("normal_font")
		GNLogger.debug("RichTextTOP", "'%s' reverted to default font" % id)
		return
	var loaded_font := GNResourceLoader.load_font(font_path, project_dir)
	if loaded_font != null:
		_loaded_font = loaded_font
		_rtl.add_theme_font_override("normal_font", _loaded_font)
		GNLogger.info("RichTextTOP", "'%s' loaded font: %s" % [id, font_path])
	else:
		GNLogger.warn("RichTextTOP", "'%s' font not found or invalid: %s" % [id, font_path])
		_loaded_font = null
		_rtl.remove_theme_font_override("normal_font")
