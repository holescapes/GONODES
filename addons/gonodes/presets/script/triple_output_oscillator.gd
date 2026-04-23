# @output chop Oscillator signals
# @output dat  Oscillator state table
# @output sop  Point cloud visualization
# @param int oscillators 6 Number of oscillators
# @param float base_freq 0.5 Base frequency
# @param float spread 1.5 Frequency spread multiplier

func cook():
	var n = par("oscillators")
	var bf = par("base_freq")
	var sp = par("spread")

	# ── Output 0 (CHOP): oscillator values ──
	for i in range(n):
		var freq = bf * pow(sp, float(i))
		var v = sin(time * TAU * freq)
		outputs[0].set_single_value("osc_%d" % i, v)

	# ── Output 1 (DAT): state table ──
	outputs[1].set_headers(PackedStringArray(["osc", "frequency", "value", "phase"]))
	for i in range(n):
		var freq = bf * pow(sp, float(i))
		var v = sin(time * TAU * freq)
		var phase = fmod(time * freq, 1.0)
		outputs[1].append_row(PackedStringArray([
			str(i), "%.3f" % freq, "%.4f" % v, "%.3f" % phase]))

	# ── Output 2 (SOP): simple point cloud of oscillator values ──
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)
	for i in range(n):
		var freq = bf * pow(sp, float(i))
		var v = sin(time * TAU * freq)
		st.set_color(Color(0.4, 0.7, 1.0).lerp(Color(1.0, 0.3, 0.3), (v + 1.0) * 0.5))
		st.add_vertex(Vector3(float(i) * 0.5 - float(n) * 0.25, v, 0.0))
	outputs[2].set_from_surface_tool(st)
