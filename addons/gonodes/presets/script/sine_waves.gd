# @output chop Output signal
# @param float speed 1.0 Animation speed
# @param int channels 4 Number of output channels
# @param float spread 0.5 Phase spread between channels

func cook():
	op.sample_rate = 60.0
	var n = par("channels")
	for i in range(n):
		var phase = i * par("spread")
		var val = sin(time * par("speed") + phase)
		op.set_single_value("wave%d" % i, val)
