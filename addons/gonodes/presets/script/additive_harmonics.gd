# @output chop Output signal
# @param float frequency 1.0 Oscillation frequency
# @param float amplitude 1.0 Peak amplitude
# @param int harmonics 3 Number of additive harmonics
# @param float decay 0.5 Harmonic amplitude decay per octave

func cook():
	var total = 0.0
	var f = par("frequency")
	var a = par("amplitude")
	for h in range(par("harmonics")):
		var harmonic_f = f * (h + 1)
		var harmonic_a = a * pow(par("decay"), float(h))
		total += sin(time * TAU * harmonic_f) * harmonic_a
	op.set_single_value("additive", total)
	op.set_single_value("fundamental", sin(time * TAU * f) * a)
