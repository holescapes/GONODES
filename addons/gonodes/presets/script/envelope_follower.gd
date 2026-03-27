# @input chop Source signal
# @param float attack 0.02 Attack time in seconds
# @param float release 0.2 Release time in seconds

var _envelope: Dictionary = {}

func setup():
	_envelope.clear()

func cook():
	var src = inputs[0] if inputs.size() > 0 else null
	if src == null or not (src is GNChannelData):
		return
	for ch_name in src.channels:
		var samples: PackedFloat32Array = src.get_channel(ch_name)
		if samples.is_empty():
			continue
		var current := absf(samples[samples.size() - 1])
		var prev: float = _envelope.get(ch_name, 0.0)
		var coeff: float
		if current > prev:
			coeff = 1.0 - exp(-dt / maxf(par("attack"), 0.001))
		else:
			coeff = 1.0 - exp(-dt / maxf(par("release"), 0.001))
		var env := lerpf(prev, current, coeff)
		_envelope[ch_name] = env
		op.set_single_value(ch_name + "_env", env)
