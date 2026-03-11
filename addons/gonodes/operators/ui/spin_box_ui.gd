class_name SpinBoxUI
extends GNUiBase
## Numeric spin box widget for PanelTOP.
##
## Outputs widget_state: {"value": <float>}

var _spinbox: SpinBox = null


func _init() -> void:
	node_type = "spinbox"
	node_description = "Numeric input with increment/decrement buttons."


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("min_val", 0.0, null, null, 0.01, "Min", "Minimum value"))
	add_parameter(GNParameter.create_float("max_val", 100.0, null, null, 0.01, "Max", "Maximum value"))
	add_parameter(GNParameter.create_float("step", 1.0, 0.001, 100.0, 0.001, "Step", "Value increment step"))
	add_parameter(GNParameter.create_float("default_val", 0.0, null, null, 0.01, "Default", "Initial value"))
	add_parameter(GNParameter.create_string("prefix", "", "Prefix", "Text before value (e.g. '$')"))
	add_parameter(GNParameter.create_string("suffix", "", "Suffix", "Text after value (e.g. '%')"))
	add_parameter(GNParameter.create_bool("editable", true, "Editable", "Allow value editing"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(120, 32), "Min Size", "Minimum widget size"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_spinbox()

	_spinbox.min_value = get_param_value("min_val")
	_spinbox.max_value = get_param_value("max_val")
	_spinbox.step = get_param_value("step")
	_spinbox.prefix = get_param_value("prefix")
	_spinbox.suffix = get_param_value("suffix")
	_spinbox.editable = get_param_value("editable")
	var ms: Vector2i = get_param_value("min_size")
	_spinbox.custom_minimum_size = Vector2(ms.x, ms.y)

	widget_state = {"value": _spinbox.value}
	return null


func _ensure_spinbox() -> void:
	if _spinbox != null:
		return
	_spinbox = SpinBox.new()
	_spinbox.name = id + "_spinbox"
	_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spinbox.min_value = get_param_value("min_val")
	_spinbox.max_value = get_param_value("max_val")
	_spinbox.step = get_param_value("step")
	_spinbox.value = get_param_value("default_val")
	_spinbox.value_changed.connect(_on_value_changed)
	_control_node = _spinbox


func _on_value_changed(_value: float) -> void:
	widget_state["value"] = _spinbox.value
	mark_dirty()


func destroy_control_node() -> void:
	if _spinbox != null and _spinbox.value_changed.is_connected(_on_value_changed):
		_spinbox.value_changed.disconnect(_on_value_changed)
	_spinbox = null
	super.destroy_control_node()
