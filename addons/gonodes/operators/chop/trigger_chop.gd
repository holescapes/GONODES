class_name TriggerCHOP
extends GNNode
## Generates one-shot trigger pulses when the input crosses a threshold.
## Similar to TouchDesigner's Trigger CHOP.
## Outputs a pulse that decays over time after being triggered.

var _active: Dictionary = {}  # channel -> { "timer": float, "triggered": bool }
var _prev_in: Dictionary = {}  # channel -> float (for edge detection)
var _cached_channel_data: GNChannelData = null


func _init() -> void:
	node_type = "trigger"
	family = GNFamily.Type.CHOP
	time_dependent = true
	node_description = "One-shot trigger pulse on threshold crossing."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input signal")
	add_output("out", GNFamily.Type.CHOP, "Trigger pulse output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("threshold", 0.5, null, null, 0.01, "", "Trigger threshold"))
	add_parameter(GNParameter.create_float("attack", 0.0, 0.0, 10.0, 0.01, "Attack (sec)", "Pulse rise time in seconds"))
	add_parameter(GNParameter.create_float("peak", 1.0, 0.0, null, 0.01, "Peak Value", "Maximum pulse value"))
	add_parameter(GNParameter.create_float("decay", 0.5, 0.0, 10.0, 0.01, "Decay (sec)", "Pulse fall time in seconds"))
	add_parameter(GNParameter.create_bool("retrigger", true, "Allow Retrigger", "Allow retriggering while active"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = inputs[0] as GNChannelData if inputs.size() > 0 and inputs[0] is GNChannelData else null
	if in_data == null:
		GNLogger.warn("TriggerCHOP", "'%s' — no valid input" % id)
		return null

	var thresh: float = get_param_value("threshold")
	var attack_time: float = get_param_value("attack")
	var peak_val: float = get_param_value("peak")
	var decay_time: float = get_param_value("decay")
	var retrig: bool = get_param_value("retrigger")
	var dt: float = current_delta

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = in_data.sample_rate

	for ch_name in in_data.channels:
		var samples: PackedFloat32Array = in_data.channels[ch_name]
		if samples.size() == 0:
			continue

		var current_val: float = samples[samples.size() - 1]
		var prev_val: float = _prev_in.get(ch_name, 0.0)
		_prev_in[ch_name] = current_val

		# Init state dict for channel
		if not _active.has(ch_name):
			_active[ch_name] = {"timer": -1.0, "triggered": false}

		var state: Dictionary = _active[ch_name]

		# Edge detection: rising cross of threshold
		if prev_val < thresh and current_val >= thresh:
			if retrig or not state["triggered"]:
				state["timer"] = 0.0
				state["triggered"] = true

		# Compute output from envelope
		var out_val: float = 0.0
		if state["timer"] >= 0.0:
			state["timer"] += dt
			var total_time: float = attack_time + decay_time
			if state["timer"] < attack_time:
				# Attack phase
				out_val = peak_val * (state["timer"] / attack_time) if attack_time > 0.0 else peak_val
			elif state["timer"] < total_time:
				# Decay phase
				var decay_elapsed: float = state["timer"] - attack_time
				out_val = peak_val * (1.0 - decay_elapsed / decay_time) if decay_time > 0.0 else 0.0
			else:
				# Done
				out_val = 0.0
				state["timer"] = -1.0
				state["triggered"] = false

		_cached_channel_data.set_single_value(ch_name, out_val)

	return _cached_channel_data
