class_name PanelExecuteDAT
extends GNDatBase
## Logs panel/UI events (press, release, hover, value change) as a DAT table.
##
## Connects to a UI operator (PanelTOP or UI widget COMP) and records
## interaction events with timestamps.
##
## TouchDesigner equivalent: Panel Execute DAT.

var _events: Array[PackedStringArray] = []
var _max_events: int = 100


func _init() -> void:
	node_type = "panel_execute"
	time_dependent = true


func _init_ports() -> void:
	add_input("panel", GNFamily.Type.CHOP, false, "UI state CHOP input (from widget)")
	add_output("out", GNFamily.Type.DAT, "Event log table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("panel_path", GNFamily.Type.UI,
		"Panel Path", "Node ID of the panel/UI operator to monitor"))
	add_parameter(GNParameter.create_int("max_events", 100, 1, 10000,
		"Max Events", "Maximum events to keep in table"))
	add_parameter(GNParameter.create_bool("log_values", true,
		"Log Values", "Log value change events"))
	add_parameter(GNParameter.create_bool("log_hover", false,
		"Log Hover", "Log hover/move events (can be noisy)"))
	add_parameter(GNParameter.create_pulse("clear",
		"Clear", "Clear event log"))


func _cook(inputs: Array[GNData]) -> GNData:
	_max_events = get_param_value("max_events")
	var log_values: bool = get_param_value("log_values")
	var clear_pulse: bool = get_param_value("clear")

	if clear_pulse:
		_events.clear()
		if parameters.has("clear"):
			parameters["clear"].value = false

	# Check for value changes in input CHOP state
	if log_values:
		var in_chop := inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
		if in_chop != null:
			for ch_name in in_chop.get_channel_names():
				var val: float = in_chop.get_value(ch_name)
				_add_event("valueChange", ch_name, "%.4f" % val)

	var out := _prepare_table()
	out.set_headers(PackedStringArray(["timestamp", "event", "channel", "value"]))
	for ev in _events:
		out.append_row(ev)

	if _events.is_empty():
		out.append_row(PackedStringArray(["", "none", "", ""]))

	return out


func _add_event(event_type: String, channel: String, value: String) -> void:
	var ts := "%.3f" % (Time.get_ticks_msec() / 1000.0)
	_events.append(PackedStringArray([ts, event_type, channel, value]))
	while _events.size() > _max_events:
		_events.remove_at(0)
