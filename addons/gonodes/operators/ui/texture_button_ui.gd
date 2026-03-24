class_name TextureButtonUI
extends GNUiBase
## Texture button widget for PanelTOP.
##
## Displays clickable textured button with optional normal/pressed/hover TOPs.
## Outputs widget_state: {"press": 0 or 1, "toggle": 0 or 1}

var _tex_btn: TextureButton = null


func _init() -> void:
	node_type = "texture_button"
	node_description = "Clickable texture button with normal/pressed/hover TOPs."


func _init_ports() -> void:
	add_input("normal", GNFamily.Type.TOP, false, "Normal state texture")
	add_input("pressed", GNFamily.Type.TOP, false, "Pressed state texture")
	add_input("hover", GNFamily.Type.TOP, false, "Hover state texture")
	add_output("out", GNFamily.Type.UI, "Widget output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("toggle_mode", false, "Toggle Mode", "Button stays pressed on click"))
	add_parameter(GNParameter.create_bool("stretch", true, "Stretch", "Ignore texture size"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(64, 64), "Min Size", "Minimum widget size"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_tex_btn()

	# Normal texture (input 0)
	if inputs.size() > 0 and inputs[0] is GNTextureData:
		_tex_btn.texture_normal = (inputs[0] as GNTextureData).texture
	else:
		_tex_btn.texture_normal = null

	# Pressed texture (input 1)
	if inputs.size() > 1 and inputs[1] is GNTextureData:
		_tex_btn.texture_pressed = (inputs[1] as GNTextureData).texture
	else:
		_tex_btn.texture_pressed = null

	# Hover texture (input 2)
	if inputs.size() > 2 and inputs[2] is GNTextureData:
		_tex_btn.texture_hover = (inputs[2] as GNTextureData).texture
	else:
		_tex_btn.texture_hover = null

	_tex_btn.toggle_mode = get_param_value("toggle_mode")
	_tex_btn.ignore_texture_size = get_param_value("stretch")
	_tex_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var ms: Vector2i = get_param_value("min_size")
	_tex_btn.custom_minimum_size = Vector2(ms.x, ms.y)

	widget_state = {
		"press": 0.0,
		"toggle": 1.0 if _tex_btn.button_pressed else 0.0,
	}
	return null


func _ensure_tex_btn() -> void:
	if _tex_btn != null:
		return
	_tex_btn = TextureButton.new()
	_tex_btn.name = id + "_texbtn"
	_tex_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tex_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tex_btn.ignore_texture_size = true
	_tex_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_tex_btn.pressed.connect(_on_pressed)
	_control_node = _tex_btn


func _on_pressed() -> void:
	widget_state["press"] = 1.0
	widget_state["toggle"] = 1.0 if _tex_btn.button_pressed else 0.0
	mark_dirty()


func destroy_control_node() -> void:
	if _tex_btn != null and _tex_btn.pressed.is_connected(_on_pressed):
		_tex_btn.pressed.disconnect(_on_pressed)
	_tex_btn = null
	super.destroy_control_node()
