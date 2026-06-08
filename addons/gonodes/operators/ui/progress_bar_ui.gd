class_name ProgressBarUI
extends GNUiBase
## Progress bar widget for PanelTOP.
##
## Accepts an optional CHOP input to drive the bar value.
## Outputs widget_state: {"value": <float>, "ratio": <float 0-1>}

var _bar: ProgressBar = null


func _init() -> void:
	node_type = "progress_bar"


func _init_ports() -> void:
	add_input("chop", GNFamily.Type.CHOP, false, "CHOP to drive bar value", "CHOP")
	add_output("out", GNFamily.Type.UI, "Widget output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("min_val", 0.0, null, null, 0.01, "Min", "Minimum value"))
	add_parameter(GNParameter.create_float("max_val", 100.0, null, null, 0.01, "Max", "Maximum value"))
	add_parameter(GNParameter.create_float("default_val", 50.0, null, null, 0.01, "Default", "Default value"))
	add_parameter(GNParameter.create_string("chop_channel", "value", "Channel", "CHOP channel name to read"))
	add_parameter(GNParameter.create_bool("show_percentage", true, "Show %", "Display percentage text"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(200, 24), "Min Size", "Minimum bar size"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_bar()

	_bar.min_value = get_param_value("min_val")
	_bar.max_value = get_param_value("max_val")
	_bar.show_percentage = get_param_value("show_percentage")
	var ms: Vector2i = get_param_value("min_size")
	_bar.custom_minimum_size = Vector2(ms.x, ms.y)

	# CHOP input drives value
	if inputs.size() > 0 and inputs[0] is GNChannelData:
		var chop: GNChannelData = inputs[0] as GNChannelData
		var ch_name: String = get_param_value("chop_channel")
		if chop.has_channel(ch_name):
			_bar.value = chop.get_value(ch_name)
	else:
		_bar.value = get_param_value("default_val")

	var range_size: float = _bar.max_value - _bar.min_value
	var ratio: float = (_bar.value - _bar.min_value) / maxf(range_size, 0.0001)
	widget_state = {
		"value": _bar.value,
		"ratio": clampf(ratio, 0.0, 1.0),
	}
	return null


func _ensure_bar() -> void:
	if _bar != null:
		return
	_bar = ProgressBar.new()
	_bar.name = id + "_progressbar"
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.min_value = get_param_value("min_val")
	_bar.max_value = get_param_value("max_val")
	_bar.value = get_param_value("default_val")
	_control_node = _bar


func destroy_control_node() -> void:
	_bar = null
	super.destroy_control_node()
