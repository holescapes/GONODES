# @input dat Step table (columns: name, value, duration)
# @output chop Current step value as channel
# @output dat  Playback state table
# @param float speed 1.0 Playback speed multiplier
# @param bool loop true Loop when reaching end

var _phase: float = 0.0

func setup():
	_phase = 0.0

func cook():
	# Parse step table from DAT input
	var steps: Array = []
	var total_dur: float = 0.0
	var dat_src = inputs[0] if inputs.size() > 0 else null
	if dat_src != null and dat_src is GNTableData:
		for r in range(dat_src.num_rows()):
			var row = dat_src.get_row(r)
			if row.size() >= 3:
				steps.append({
					"name": row[0], "value": float(row[1]),
					"duration": maxf(float(row[2]), 0.01)
				})
				total_dur += maxf(float(row[2]), 0.01)

	if steps.is_empty():
		# No input — generate a default 4-step sequence
		steps = [
			{"name": "low", "value": 0.0, "duration": 1.0},
			{"name": "rise", "value": 0.5, "duration": 0.5},
			{"name": "high", "value": 1.0, "duration": 1.0},
			{"name": "fall", "value": 0.25, "duration": 0.5},
		]
		total_dur = 3.0

	_phase += dt * par("speed")
	if par("loop") and total_dur > 0.0:
		_phase = fmod(_phase, total_dur)

	# Find current step
	var elapsed_in_seq = _phase
	var step_idx = 0
	var step_progress = 0.0
	for i in range(steps.size()):
		if elapsed_in_seq < steps[i]["duration"]:
			step_idx = i
			step_progress = elapsed_in_seq / steps[i]["duration"]
			break
		elapsed_in_seq -= steps[i]["duration"]

	var current = steps[step_idx]

	# Output 0: CHOP — current value
	outputs[0].set_single_value("value", current["value"])
	outputs[0].set_single_value("progress", step_progress)
	outputs[0].set_single_value("step", float(step_idx))

	# Output 1: DAT — playback state
	outputs[1].set_headers(PackedStringArray(["property", "value"]))
	outputs[1].append_row(PackedStringArray(["current_step", current["name"]]))
	outputs[1].append_row(PackedStringArray(["step_index", str(step_idx)]))
	outputs[1].append_row(PackedStringArray(["step_value", "%.4f" % current["value"]]))
	outputs[1].append_row(PackedStringArray(["step_progress", "%.3f" % step_progress]))
	outputs[1].append_row(PackedStringArray(["total_phase", "%.3f" % _phase]))
	outputs[1].append_row(PackedStringArray(["total_steps", str(steps.size())]))
