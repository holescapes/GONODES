# @output chop Output signal
# @param float bpm 120.0 Beats per minute
# @param float swing 0.0 Swing amount (0-1)

func cook():
	var bps = par("bpm") / 60.0
	var beat = time * bps
	var beat_frac = fmod(beat, 1.0)
	var bar_frac = fmod(beat, 4.0) / 4.0
	var measure = int(beat) / 4

	op.set_single_value("beat", beat)
	op.set_single_value("beat_frac", beat_frac)
	op.set_single_value("bar", bar_frac)
	op.set_single_value("measure", float(measure))
	op.set_single_value("pulse", 1.0 if beat_frac < 0.1 else 0.0)
	op.set_single_value("bps", bps)
