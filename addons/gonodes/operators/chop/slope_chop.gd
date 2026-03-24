class_name SlopeCHOP
extends GNChopBase
## Computes the derivative (rate-of-change) of each channel, sample by sample.
##
## 1st derivative: output[i] = (input[i] - input[i-1]) / Δt
## 2nd derivative: output[i] = (d1[i] - d1[i-1]) / Δt
##
## Equivalent to TouchDesigner's Slope CHOP.
## Useful for extracting velocity, acceleration, or edge/onset detection.

var _prev1: Dictionary = {}    # channel_name → last input value
var _prev_d1: Dictionary = {}  # channel_name → last 1st-derivative value


func _init() -> void:
	node_type = "slope"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels")
	add_output("out", GNFamily.Type.CHOP, "Derivative channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("order",
		PackedStringArray(["1st Derivative", "2nd Derivative"]), 0, "",
		"Order of differentiation"))
	add_parameter(GNParameter.create_bool("normalize", true,
		"Normalize by Δt", "Divide by sample interval to give units per second"))
	add_parameter(GNParameter.create_float("multiply", 1.0, null, null, 0.01,
		"Multiply", "Output scale factor"))
	add_parameter(GNParameter.create_bool("reset", false, "",
		"Reset derivative state (clear history)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		return null

	var order: int    = get_param_value("order")
	var normalize: bool = get_param_value("normalize")
	var mult: float   = get_param_value("multiply")
	var do_reset: bool = get_param_value("reset")

	if do_reset:
		_prev1.clear()
		_prev_d1.clear()

	var out: GNChannelData = _prepare_output(in_data.sample_rate)
	# If normalize, dt = 1/sample_rate (seconds per sample); else unit step of 1.
	var dt: float = 1.0 / maxf(in_data.sample_rate, 1.0) if normalize else 1.0

	for ch_name: String in in_data.channels:
		var samples: PackedFloat32Array = in_data.channels[ch_name]
		if samples.is_empty():
			continue
		var out_s := PackedFloat32Array()
		out_s.resize(samples.size())

		# Seed history from first sample when not yet initialised.
		var p1: float  = _prev1.get(ch_name,  float(samples[0]))
		var pd1: float = _prev_d1.get(ch_name, 0.0)

		for i in range(samples.size()):
			var v: float  = samples[i]
			var d1: float = (v - p1) / dt
			if order == 0:
				out_s[i] = d1 * mult
			else:  # 2nd derivative
				var d2: float = (d1 - pd1) / dt
				out_s[i] = d2 * mult
			pd1 = d1
			p1  = v

		_prev1[ch_name]  = p1
		_prev_d1[ch_name] = pd1
		out.set_channel(ch_name, out_s)

	return out
