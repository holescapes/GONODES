class_name TextureProgressBarUI
extends GNUiBase
## Textured progress bar widget for PanelTOP.
##
## Displays a TextureProgressBar with TOP inputs for under/progress/over textures.
## Optional CHOP input drives the value.
## Outputs widget_state: {"value": <float>, "ratio": <float>}

var _progress: TextureProgressBar = null


func _init() -> void:
	node_type = "textureprogressbar"
	node_description = "Textured progress bar with TOP layers. Optional CHOP driver."


func _init_ports() -> void:
	add_input("chop", GNFamily.Type.CHOP, false, "CHOP value driver")
	add_input("under", GNFamily.Type.TOP, false, "Under/background texture")
	add_input("progress", GNFamily.Type.TOP, false, "Progress fill texture")
	add_input("over", GNFamily.Type.TOP, false, "Over/foreground texture")
	add_output("out", GNFamily.Type.UI, "Widget output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("min_val", 0.0, null, null, 0.01, "Min", "Minimum value"))
	add_parameter(GNParameter.create_float("max_val", 100.0, null, null, 0.01, "Max", "Maximum value"))
	add_parameter(GNParameter.create_float("default_val", 0.0, null, null, 0.01, "Default", "Initial value"))
	add_parameter(GNParameter.create_string("chop_channel", "value", "Channel", "CHOP channel name for driven value"))
	add_parameter(GNParameter.create_int("fill_mode", 0, 0, 5, "Fill Mode", "0=L→R 1=R→L 2=T→B 3=B→T 4=CW 5=CCW"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(200, 32), "Min Size", "Minimum widget size"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_progress()

	_progress.min_value = get_param_value("min_val")
	_progress.max_value = get_param_value("max_val")
	_progress.fill_mode = get_param_value("fill_mode")
	var ms: Vector2i = get_param_value("min_size")
	_progress.custom_minimum_size = Vector2(ms.x, ms.y)

	# CHOP driver (input 0)
	if inputs.size() > 0 and inputs[0] is GNChannelData:
		var chop: GNChannelData = inputs[0] as GNChannelData
		var ch_name: String = get_param_value("chop_channel")
		_progress.value = chop.get_value(ch_name)
	
	# Under texture (input 1)
	if inputs.size() > 1 and inputs[1] is GNTextureData:
		_progress.texture_under = (inputs[1] as GNTextureData).texture
	else:
		_progress.texture_under = null

	# Progress texture (input 2)
	if inputs.size() > 2 and inputs[2] is GNTextureData:
		_progress.texture_progress = (inputs[2] as GNTextureData).texture
	else:
		_progress.texture_progress = null

	# Over texture (input 3)
	if inputs.size() > 3 and inputs[3] is GNTextureData:
		_progress.texture_over = (inputs[3] as GNTextureData).texture
	else:
		_progress.texture_over = null

	var range_size: float = _progress.max_value - _progress.min_value
	widget_state = {
		"value": _progress.value,
		"ratio": (_progress.value - _progress.min_value) / range_size if range_size > 0.0 else 0.0,
	}
	return null


func _ensure_progress() -> void:
	if _progress != null:
		return
	_progress = TextureProgressBar.new()
	_progress.name = id + "_texprogress"
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_progress.value = get_param_value("default_val")
	_progress.value_changed.connect(_on_value_changed)
	_control_node = _progress


func _on_value_changed(value: float) -> void:
	var range_size: float = _progress.max_value - _progress.min_value
	widget_state["value"] = value
	widget_state["ratio"] = (value - _progress.min_value) / range_size if range_size > 0.0 else 0.0
	mark_dirty()


func destroy_control_node() -> void:
	if _progress != null and _progress.value_changed.is_connected(_on_value_changed):
		_progress.value_changed.disconnect(_on_value_changed)
	_progress = null
	super.destroy_control_node()
