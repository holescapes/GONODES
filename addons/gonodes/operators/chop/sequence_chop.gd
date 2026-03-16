class_name SequenceCHOP
extends GNChopBase
## Sequence CHOP inputs end-to-end in time.
##
## Each connected input plays back for its **duration** (seconds).  As
## [member elapsed_time] advances, the output transitions from input 0
## to input 1, etc.  A **crossfade** parameter (seconds) blends the
## tail of one segment with the head of the next.
##
## TouchDesigner equivalent: Sequence CHOP.


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "sequence"
	time_dependent = true
	node_description = "Sequence CHOP inputs end-to-end in time."
	_enable_dynamic_inputs(GNFamily.Type.CHOP)


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "First CHOP input")
	add_output("out", GNFamily.Type.CHOP, "Sequenced channel data")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("duration", 2.0, 0.001, null, 0.01,
		"Duration", "Seconds per input segment"))
	add_parameter(GNParameter.create_float("crossfade", 0.0, 0.0, null, 0.01,
		"Crossfade", "Blend time (seconds) between segments"))
	add_parameter(GNParameter.create_bool("loop", true,
		"Loop", "Loop back to first input after last"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	# Collect valid inputs
	var valid: Array[GNChannelData] = []
	for inp in inputs:
		if inp is GNChannelData:
			valid.append(inp as GNChannelData)
	if valid.is_empty():
		return null

	var seg_dur: float = maxf(get_param_value("duration"), 0.001)
	var xfade: float = maxf(get_param_value("crossfade"), 0.0)
	var do_loop: bool = get_param_value("loop")
	var n := valid.size()
	var total_dur := seg_dur * n

	# Map elapsed_time into our sequence range
	var t := elapsed_time
	if do_loop and total_dur > 0.0:
		t = fmod(t, total_dur)
		if t < 0.0:
			t += total_dur
	else:
		t = clampf(t, 0.0, total_dur - 0.001)

	# Which segment are we in?
	var seg_f := t / seg_dur
	var seg_idx := clampi(int(seg_f), 0, n - 1)
	var seg_local := fmod(t, seg_dur) / seg_dur  # 0..1 within segment

	var out := _prepare_output(60.0)

	# Primary input
	var primary: GNChannelData = valid[seg_idx]

	# Check if we're in the crossfade region at end of segment
	var xfade_norm := xfade / seg_dur if seg_dur > 0.0 else 0.0
	xfade_norm = clampf(xfade_norm, 0.0, 0.5)
	if xfade_norm > 0.0 and seg_local > (1.0 - xfade_norm):
		var next_idx := (seg_idx + 1) % n if do_loop else mini(seg_idx + 1, n - 1)
		if next_idx != seg_idx:
			var blend := (seg_local - (1.0 - xfade_norm)) / xfade_norm
			blend = clampf(blend, 0.0, 1.0)
			var secondary: GNChannelData = valid[next_idx]
			# Blend primary → secondary
			for ch_name in primary.get_channel_names():
				var v_a: float = primary.get_value(ch_name)
				var v_b: float = secondary.get_value(ch_name) if secondary.channels.has(ch_name) else 0.0
				out.set_single_value(ch_name, lerpf(v_a, v_b, blend))
			# Add channels only in secondary
			for ch_name in secondary.get_channel_names():
				if not primary.channels.has(ch_name):
					out.set_single_value(ch_name, secondary.get_value(ch_name) * blend)
			return out

	# No crossfade needed — output primary directly
	for ch_name in primary.get_channel_names():
		out.set_single_value(ch_name, primary.get_value(ch_name))

	return out
