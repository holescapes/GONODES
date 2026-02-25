class_name TextTOP
extends GNNode
## Renders text onto a texture using Godot's Label node.
## Similar to TouchDesigner's Text TOP.

var _viewport: SubViewport = null
var _label: Label = null
var _bg: ColorRect = null
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "text"
	family = GNFamily.Type.TOP


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("text", "Hello"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 256)))
	add_parameter(GNParameter.create_int("font_size", 48, 8, 256))
	add_parameter(GNParameter.create_color("font_color", Color.WHITE))
	add_parameter(GNParameter.create_color("bg_color", Color.BLACK))
	add_parameter(GNParameter.create_enum("align_h",
		PackedStringArray(["Left", "Center", "Right"]), 1))
	add_parameter(GNParameter.create_enum("align_v",
		PackedStringArray(["Top", "Center", "Bottom"]), 1))
	add_parameter(GNParameter.create_bool("word_wrap", true))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_viewport()

	var txt: String = get_param_value("text")
	var res: Vector2i = get_param_value("resolution")
	var fsize: int = get_param_value("font_size")
	var fcol: Color = get_param_value("font_color")
	var bgcol: Color = get_param_value("bg_color")
	var ah: int = get_param_value("align_h")
	var av: int = get_param_value("align_v")
	var wrap: bool = get_param_value("word_wrap")

	if _viewport.size != res:
		_viewport.size = res
		_bg.size = Vector2(res)
		_label.size = Vector2(res)

	_bg.color = bgcol

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


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_viewport = SubViewport.new()
	_viewport.name = "VP_%s" % id
	_viewport.size = Vector2i(512, 256)
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	add_child(_viewport)

	_bg = ColorRect.new()
	_bg.name = "BG"
	_bg.size = Vector2(512, 256)
	_bg.color = Color.BLACK
	_viewport.add_child(_bg)

	_label = Label.new()
	_label.name = "TextLabel"
	_label.size = Vector2(512, 256)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_viewport.add_child(_label)

	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size
	GNLogger.debug("TextTOP", "'%s' viewport created" % id)
