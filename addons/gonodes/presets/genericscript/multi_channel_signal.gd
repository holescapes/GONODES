# @output chop Multi-channel signal
# @output top  Visualization texture
# @param float frequency 2.0 Signal frequency
# @param int channels 4 Number of channels

func cook():
	# ── Output 0 (CHOP): generate phase-spread sine waves ──
	for i in range(par("channels")):
		var phase = i * TAU / par("channels")
		var v = sin(time * par("frequency") + phase)
		outputs[0].set_single_value("ch%d" % i, v)

	# ── Output 1 (TOP): nothing to do here — just pass a color ──
	# (TOP outputs require shader-level code or upstream textures;
	#  this placeholder demonstrates the port wiring.)
	pass
