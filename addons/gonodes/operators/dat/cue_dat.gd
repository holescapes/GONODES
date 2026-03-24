class_name CueDAT
extends GNDatBase
## Cue list manager — stores and sequences named cue entries as a table.
##
## Each row defines a cue with name, start time, duration, transition type,
## and a JSON data payload of parameter overrides.  Can be edited inline,
## loaded from JSON, or built by upstream DAT chains.
##
## The output table has columns: index, name, time, duration, transition, data.
##
## Used as input to CueCHOP which reads the table and sequences cues.
##
## TouchDesigner equivalent: no direct equivalent — combines aspects of
## Timer CHOP cue points + custom cue scripting.

const MAX_CUES := 64


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "cue"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, true, "Optional upstream cue table (overrides built-in rows)")
	add_output("out", GNFamily.Type.DAT, "Cue table (index, name, time, duration, transition, data)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("num_cues", 1, 1, MAX_CUES,
		"Cues", "Number of cue entries"))

	# Per-cue parameters (up to MAX_CUES, but only num_cues are active)
	for i in range(MAX_CUES):
		var prefix := "cue%d_" % i
		var label_prefix := "Cue %d " % i
		add_parameter(GNParameter.create_string(prefix + "name", "cue_%d" % i,
			label_prefix + "Name", "Cue name / label"))
		add_parameter(GNParameter.create_float(prefix + "time", float(i) * 5.0, -1.0, null, 0.1,
			label_prefix + "Time", "Start time in seconds (-1 = wait for trigger)"))
		add_parameter(GNParameter.create_float(prefix + "duration", 5.0, 0.0, null, 0.1,
			label_prefix + "Duration", "Duration in seconds (0 = indefinite)"))
		add_parameter(GNParameter.create_string(prefix + "transition", "cut",
			label_prefix + "Transition", "Transition type: cut, fade:seconds"))
		add_parameter(GNParameter.create_string(prefix + "data", "{}",
			label_prefix + "Data", "JSON dict of node_id/param: value overrides"))


## Override to control parameter visibility — only show active cues.
func is_parameter_visible(param_name: String) -> bool:
	if not param_name.begins_with("cue"):
		return true
	# Extract cue index from param name like "cue3_name"
	var parts := param_name.split("_", true, 2)
	if parts.size() < 2:
		return true
	var idx_str := parts[0].substr(3)  # strip "cue" prefix
	if not idx_str.is_valid_int():
		return true
	var idx := idx_str.to_int()
	return idx < get_param_value("num_cues")


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	var table := _prepare_table()
	table.set_headers(PackedStringArray(["index", "name", "time", "duration", "transition", "data"]))

	# If upstream DAT is connected, pass it through as the cue source
	var upstream := _get_input_dat(inputs, 0)
	if upstream != null and upstream.num_rows() > 0:
		for r in range(upstream.num_rows()):
			var row := PackedStringArray()
			for c in range(6):
				if c < upstream.num_cols():
					row.append(upstream.cell(r, c))
				else:
					row.append("")
			table.append_row(row)
		return table

	# Otherwise build from parameter cues
	var num: int = clampi(get_param_value("num_cues"), 1, MAX_CUES)
	for i in range(num):
		var prefix := "cue%d_" % i
		var cue_name: String = get_param_value(prefix + "name")
		var cue_time: float = get_param_value(prefix + "time")
		var cue_dur: float = get_param_value(prefix + "duration")
		var cue_trans: String = get_param_value(prefix + "transition")
		var cue_data: String = get_param_value(prefix + "data")

		table.append_row(PackedStringArray([
			str(i),
			cue_name,
			"%.3f" % cue_time,
			"%.3f" % cue_dur,
			cue_trans,
			cue_data,
		]))

	return table
