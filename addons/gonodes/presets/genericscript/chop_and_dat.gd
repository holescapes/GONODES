# @input chop Signal source
# @output chop Processed signal
# @output dat  Signal info table
# @param float gain 1.0 Output gain multiplier
# @param float offset 0.0 DC offset

func cook():
	# ── Output 0 (CHOP): process input or generate sine ──
	if inputs.size() > 0 and inputs[0]:
		for ch in inputs[0].get_channel_names():
			var v = inputs[0].get_value(ch) * par("gain") + par("offset")
			outputs[0].set_single_value(ch, v)
	else:
		outputs[0].set_single_value("out", sin(time) * par("gain") + par("offset"))

	# ── Output 1 (DAT): info table ──
	outputs[1].set_headers(PackedStringArray(["key", "value"]))
	outputs[1].append_row(PackedStringArray(["time", "%.3f" % time]))
	outputs[1].append_row(PackedStringArray(["frame", str(frame)]))
	outputs[1].append_row(PackedStringArray(["gain", str(par("gain"))]))
