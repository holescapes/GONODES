# @output chop Output signal
# @input chop Source channels to smooth
# @param float smoothing 0.1 Smoothing factor (0=instant, 1=frozen)

var _prev_values: Dictionary = {}

func setup():
	_prev_values.clear()

func cook():
	var src = inputs[0] if inputs.size() > 0 else null
	if src == null or not (src is GNChannelData):
		return
	var alpha = clampf(par("smoothing"), 0.0, 0.999)
	for ch_name in src.channels:
		var samples: PackedFloat32Array = src.get_channel(ch_name)
		if samples.is_empty():
			continue
		var current = samples[samples.size() - 1]
		var prev = _prev_values.get(ch_name, current)
		var smoothed = lerpf(prev, current, 1.0 - alpha)
		_prev_values[ch_name] = smoothed
		op.set_single_value(ch_name, smoothed)
