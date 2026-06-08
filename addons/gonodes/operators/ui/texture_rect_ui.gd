class_name TextureRectUI
extends GNUiBase
## Texture display widget for PanelTOP.
##
## Displays a TOP input as a TextureRect inside the panel.
## Accepts an optional MAT input to apply a ShaderMaterial overlay.
## Outputs widget_state: {"has_texture": 0 or 1}

var _tex_rect: TextureRect = null


func _init() -> void:
	node_type = "texture_rect"


func _init_ports() -> void:
	add_input("top", GNFamily.Type.TOP, false, "Texture to display", "TOP")
	add_input("mat", GNFamily.Type.MAT, false, "Shader material overlay", "Material")
	add_output("out", GNFamily.Type.UI, "Widget output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("stretch_mode",
		PackedStringArray(["Scale", "Tile", "Keep", "Keep Centered", "Keep Aspect", "Keep Aspect Centered", "Keep Aspect Covered"]),
		4, "Stretch", "How the texture fills the rect"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(256, 256), "Min Size", "Minimum display size"))
	add_parameter(GNParameter.create_bool("expand_mode", true, "Expand", "Ignore texture size for layout"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_tex_rect()

	# TOP input → texture
	var has_tex := false
	if inputs.size() > 0 and inputs[0] is GNTextureData:
		var tex_data: GNTextureData = inputs[0] as GNTextureData
		if tex_data.texture != null:
			_tex_rect.texture = tex_data.texture
			has_tex = true
	if not has_tex:
		_tex_rect.texture = null

	# MAT input → material
	if inputs.size() > 1 and inputs[1] is GNMaterialData:
		var mat_data: GNMaterialData = inputs[1] as GNMaterialData
		_tex_rect.material = mat_data.material
	else:
		_tex_rect.material = null

	var stretch: int = get_param_value("stretch_mode")
	_tex_rect.stretch_mode = stretch as TextureRect.StretchMode
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE if get_param_value("expand_mode") else TextureRect.EXPAND_KEEP_SIZE
	var ms: Vector2i = get_param_value("min_size")
	_tex_rect.custom_minimum_size = Vector2(ms.x, ms.y)

	widget_state = {"has_texture": 1.0 if has_tex else 0.0}
	return null


func _ensure_tex_rect() -> void:
	if _tex_rect != null:
		return
	_tex_rect = TextureRect.new()
	_tex_rect.name = id + "_texrect"
	_tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_control_node = _tex_rect


func destroy_control_node() -> void:
	_tex_rect = null
	super.destroy_control_node()
