# @input chop Signal to analyze
# @output chop Analyzed metrics
# @output dat  Statistics table

func cook():
	var src = inputs[0] if inputs.size() > 0 else null
	if src == null or not (src is GNChannelData):
		outputs[0].set_single_value("status", 0.0)
		return

	outputs[1].set_headers(PackedStringArray(["channel", "min", "max", "avg", "rms"]))

	for ch_name in src.get_channel_names():
		var samples := src.get_channel(ch_name)
		if samples.is_empty():
			continue
		var mn := INF
		var mx := -INF
		var sum := 0.0
		var sq_sum := 0.0
		for s in samples:
			mn = minf(mn, s)
			mx = maxf(mx, s)
			sum += s
			sq_sum += s * s
		var avg := sum / samples.size()
		var rms := sqrt(sq_sum / samples.size())

		outputs[0].set_single_value(ch_name + "_min", mn)
		outputs[0].set_single_value(ch_name + "_max", mx)
		outputs[0].set_single_value(ch_name + "_avg", avg)
		outputs[0].set_single_value(ch_name + "_rms", rms)

		outputs[1].append_row(PackedStringArray([
			ch_name, "%.4f" % mn, "%.4f" % mx, "%.4f" % avg, "%.4f" % rms]))
