class_name TextTOP
extends GNTopBase
## Renders text onto a texture using Godot's Label node.
## Similar to TouchDesigner's Text TOP.

var _label: Label = null
var _bg: ColorRect = null
var _loaded_font: Font = null
var _loaded_font_path: String = ""


func _init() -> void:
	node_type = "text"
	node_description = "Renders text to a texture via a Label in a SubViewport."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Rendered text texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("text", "Hello", "", "Text content to display"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 256), "", "Output texture resolution in pixels"))
	add_parameter(GNParameter.create_file("font_file", "",
		PackedStringArray(["*.ttf", "*.otf", "*.woff", "*.woff2", "*.tres", "*.res"]),
		"", "Font file from project (TTF, OTF, WOFF). Leave empty for default font."))
	add_parameter(GNParameter.create_int("font_size", 48, 8, 256, "", "Font size in pixels"))
	add_parameter(GNParameter.create_color("font_color", Color.WHITE, "", "Text color"))
	add_parameter(GNParameter.create_color("bg_color", Color.BLACK, "", "Background color"))
	add_parameter(GNParameter.create_enum("align_h",
		PackedStringArray(["Left", "Center", "Right"]), 1, "", "Horizontal text alignment"))
	add_parameter(GNParameter.create_enum("align_v",
		PackedStringArray(["Top", "Center", "Bottom"]), 1, "", "Vertical text alignment"))
	add_parameter(GNParameter.create_bool("word_wrap", true, "", "Wrap text at texture edges"))


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

	if _viewport.size != res:
		_viewport.size = res

	_bg.color = bgcol

	# Load custom font if path changed
	_apply_font(font_path)

	_label.text = txt
	_label.add_theme_font_size_override("font_size", fsize)
	_label.add_theme_color_override("font_color", fcol)

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

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _setup_viewport() -> void:
	if _viewport != null:
		return

	_ensure_viewport(get_param_value("resolution"), false)

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
	if not ResourceLoader.exists(font_path):
		GNLogger.warn("TextTOP", "'%s' font not found: %s" % [id, font_path])
		_loaded_font = null
		_label.remove_theme_font_override("font")
		return
	var res := ResourceLoader.load(font_path)
	if res is Font:
		_loaded_font = res as Font
		_label.add_theme_font_override("font", _loaded_font)
		GNLogger.info("TextTOP", "'%s' loaded font: %s" % [id, font_path])
	else:
		GNLogger.warn("TextTOP", "'%s' resource is not a Font: %s" % [id, font_path])
		_loaded_font = null
		_label.remove_theme_font_override("font")
