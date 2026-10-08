class_name TextTOP
extends GNTopBase
## Renders text onto a texture using Godot's Label node.
## Similar to TouchDesigner's Text TOP.
## Supports outline and drop shadow via Label theme overrides.

var _label: Label = null
var _bg: ColorRect = null
var _loaded_font: Font = null
var _loaded_font_path: String = ""


func _init() -> void:
	node_type = "text"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Rendered text texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("text", "Hello", "Text",
		"Text content to display (supports multiple lines)", true))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 256), "Resolution", "Output texture resolution in pixels"))
	add_parameter(GNParameter.create_file("font_file", "Path to the font file",
		PackedStringArray(["*.ttf", "*.otf", "*.woff", "*.woff2", "*.tres", "*.res"]),
		"", "Font file from project (TTF, OTF, WOFF). Leave empty for default font."))
	add_parameter(GNParameter.create_int("font_size", 48, 8, 256, "Font Size", "Font size in pixels"))
	add_parameter(GNParameter.create_color("font_color", Color.WHITE, "Font Color", "Text color"))
	add_parameter(GNParameter.create_color("bg_color", Color.BLACK, "Bg Color", "Background color"))
	add_parameter(GNParameter.create_enum("align_h",
		PackedStringArray(["Left", "Center", "Right"]), 1, "", "Horizontal text alignment"))
	add_parameter(GNParameter.create_enum("align_v",
		PackedStringArray(["Top", "Center", "Bottom"]), 1, "", "Vertical text alignment"))
	add_parameter(GNParameter.create_bool("word_wrap", true, "Word Wrap", "Wrap text at texture edges"))
	# Outline / shadow — Godot Label theme items (portable, no custom shader)
	add_parameter(GNParameter.create_int("outline_size", 0, 0, 64, "Outline Size",
		"Glyph outline width in pixels (0 = off)"))
	add_parameter(GNParameter.create_color("outline_color", Color(0, 0, 0, 1), "Outline Color",
		"Outline color (ignored when outline size is 0)"))
	add_parameter(GNParameter.create_bool("shadow", false, "Shadow",
		"Enable drop shadow behind glyphs"))
	add_parameter(GNParameter.create_color("shadow_color", Color(0, 0, 0, 0.6), "Shadow Color",
		"Drop shadow color"))
	add_parameter(GNParameter.create_vector2i("shadow_offset", Vector2i(2, 2), "Shadow Offset",
		"Drop shadow offset in pixels"))
	add_parameter(GNParameter.create_vector2i("margin", Vector2i(0, 0), "Margin",
		"Inset from the texture edges in pixels (left/top; also right/bottom)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_setup_viewport()

	var txt: String = get_param_value("text")
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

	# Load custom font if path changed
	_apply_font(font_path)

	_label.text = txt
	_label.add_theme_font_size_override("font_size", fsize)
	_label.add_theme_color_override("font_color", fcol)

	# Outline
	if outline_sz > 0:
		_label.add_theme_constant_override("outline_size", outline_sz)
		_label.add_theme_color_override("font_outline_color", outline_col)
	else:
		_label.remove_theme_constant_override("outline_size")
		_label.remove_theme_color_override("font_outline_color")

	# Drop shadow
	if use_shadow:
		_label.add_theme_color_override("font_shadow_color", shadow_col)
		_label.add_theme_constant_override("shadow_offset_x", shadow_off.x)
		_label.add_theme_constant_override("shadow_offset_y", shadow_off.y)
	else:
		_label.remove_theme_color_override("font_shadow_color")
		_label.remove_theme_constant_override("shadow_offset_x")
		_label.remove_theme_constant_override("shadow_offset_y")

	# Horizontal alignment
	match ah:
		0:
			_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		1:
			_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		2:
			_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Vertical alignment
	match av:
		0:
			_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		1:
			_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		2:
			_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF

	# Edge inset (top-left margin for HUD overlays, etc.)
	var mx := maxi(margin.x, 0)
	var my := maxi(margin.y, 0)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = float(mx)
	_label.offset_top = float(my)
	_label.offset_right = float(-mx)
	_label.offset_bottom = float(-my)

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

	_label = Label.new()
	_label.name = "TextLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_viewport.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Loads and applies a custom font, or reverts to the default theme font.
func _apply_font(font_path: String) -> void:
	if font_path == _loaded_font_path:
		return  # No change
	_loaded_font_path = font_path
	if font_path.is_empty():
		_loaded_font = null
		_label.remove_theme_font_override("font")
		GNLogger.debug("TextTOP", "'%s' reverted to default font" % id)
		return
	var loaded_font := GNResourceLoader.load_font(font_path, project_dir)
	if loaded_font != null:
		_loaded_font = loaded_font
		_label.add_theme_font_override("font", _loaded_font)
		GNLogger.info("TextTOP", "'%s' loaded font: %s" % [id, font_path])
	else:
		GNLogger.warn("TextTOP", "'%s' font not found or invalid: %s" % [id, font_path])
		_loaded_font = null
		_label.remove_theme_font_override("font")
