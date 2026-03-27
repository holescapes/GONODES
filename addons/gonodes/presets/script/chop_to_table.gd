# @input chop Source channel data to convert
# @param bool headers true Include header row with channel names
# @param bool transpose false Rows=channels (true) vs Rows=samples (false)

func cook():
	var chop_in = inputs[0] if inputs.size() > 0 else null
	if chop_in == null or not (chop_in is GNChannelData):
		op.set_headers(PackedStringArray(["(no input)"]))
		return

	var ch_names = chop_in.get_channel_names()
	if ch_names.is_empty():
		return

	if par("transpose"):
		# Each row is a channel: [name, val0, val1, ...]
		if par("headers"):
			var hdr := PackedStringArray(["channel"])
			for s in range(chop_in.length):
				hdr.append("s%d" % s)
			op.set_headers(hdr)
		for ch_name in ch_names:
			var samples = chop_in.get_channel(ch_name)
			var row := PackedStringArray([ch_name])
			for s in range(samples.size()):
				row.append("%.4f" % samples[s])
			op.append_row(row)
	else:
		# Each row is a sample: [s0_ch0, s0_ch1, ...]
		if par("headers"):
			op.set_headers(ch_names)
		for s in range(chop_in.length):
			var row := PackedStringArray()
			for ch_name in ch_names:
				var samples = chop_in.get_channel(ch_name)
				if s < samples.size():
					row.append("%.4f" % samples[s])
				else:
					row.append("0")
			op.append_row(row)
