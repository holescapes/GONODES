class_name HoldCHOP
extends GNNode
## Sample-and-hold: captures the input value when triggered and holds it.
## Similar to TouchDesigner's Hold CHOP.

var _held_values: Dictionary = {}  # channel -> float
var _prev_trigger: float = 0.0
var _cached_channel_data: GNChannelData = null


func _init() -> void:
	node_type = "hold"
	family = GNFamily.Type.CHOP
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP)
	add_input("trigger", GNFamily.Type.CHOP)
	add_output("out", GNFamily.Type.CHOP)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("threshold", 0.5, null, null, 0.01))
	add_parameter(GNParameter.create_bool("hold_on_start", true,
		"Capture initial value on first cook"))
	add_parameter(GNParameter.create_bool("reset", false))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	var trigger_data: GNChannelData = inputs[1] as GNChannelData if inputs.size() > 1 and inputs[1] is GNChannelData else null

	if in_data == null:
		GNLogger.warn("HoldCHOP", "'%s' — no valid input" % id)
		return null

	var thresh: float = get_param_value("threshold")
	var hold_start: bool = get_param_value("hold_on_start")
	var do_reset: bool = get_param_value("reset")

	if do_reset:
		_held_values.clear()
		_prev_trigger = 0.0

	# Check trigger signal
	var trigger_val: float = 0.0
	if trigger_data != null:
		for ch_name in trigger_data.channels:
			var s: PackedFloat32Array = trigger_data.channels[ch_name]
			if s.size() > 0:
				trigger_val = s[s.size() - 1]
				break

	# Rising edge detection on trigger
	var should_capture: bool = false
	if _prev_trigger < thresh and trigger_val >= thresh:
		should_capture = true
	_prev_trigger = trigger_val

	# Capture on first cook if enabled
	if hold_start and _held_values.is_empty():
		should_capture = true

	# Update held values if triggered
	if should_capture:
		for ch_name in in_data.channels:
			var s: PackedFloat32Array = in_data.channels[ch_name]
			if s.size() > 0:
				_held_values[ch_name] = s[s.size() - 1]

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = in_data.sample_rate

	# Output held values or current values if nothing held yet
	for ch_name in in_data.channels:
		if _held_values.has(ch_name):
			_cached_channel_data.set_single_value(ch_name, _held_values[ch_name])
		else:
			var s: PackedFloat32Array = in_data.channels[ch_name]
			if s.size() > 0:
				_cached_channel_data.set_single_value(ch_name, s[s.size() - 1])

	return _cached_channel_data
