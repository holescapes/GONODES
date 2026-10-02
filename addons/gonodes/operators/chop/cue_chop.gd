class_name CueCHOP
extends GNChopBase
## Cue sequencer — reads a cue table (from CueDAT) and outputs the current
## cue state as CHOP channels.  Supports both timeline-driven (auto) and
## manual (trigger) cue advancement.
##
## When a cue activates, its JSON data{} payload is applied as parameter
## overrides via the cook engine's set_par() mechanism.
##
## Outputs: active_cue, cue_progress, transition, next_cue, cue_elapsed,
##          cue_remaining.
##
## TouchDesigner equivalent: Timer CHOP (cue mode) + custom callbacks.

enum CueSource { TIMELINE, MANUAL }

var _active_cue_idx: int = -1
var _cue_start_time: float = 0.0
var _transition_progress: float = 1.0
var _prev_trigger_val: float = 0.0


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "cue_sequencer"
	time_dependent = true
	thread_safe = false  # calls engine.set_par() on other nodes


func _init_ports() -> void:
	add_input("cues", GNFamily.Type.DAT, false, "Cue table (from CueDAT or any DAT with cue columns)", "Cues")
	add_input("trigger", GNFamily.Type.CHOP, true, "Optional trigger CHOP — rising edge advances cue", "Trigger")
	add_output("out", GNFamily.Type.CHOP, "Cue state channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("source",
		PackedStringArray(["Timeline", "Manual"]),
		CueSource.TIMELINE, "Source", "Timeline = auto by time, Manual = trigger only"))
	add_parameter(GNParameter.create_string("timeline", "Timeline to sync with",
		"Timeline", "Node ID of TimelineCHOP for auto mode (empty = use engine time)"))
	add_parameter(GNParameter.create_pulse("go_next",
		"Go Next", "Advance to next cue"))
	add_parameter(GNParameter.create_pulse("go_prev",
		"Go Prev", "Go back one cue"))
	add_parameter(GNParameter.create_int("go_to", -1, -1, 999,
		"Go To", "Jump to cue index (-1 = disabled)"))
	add_parameter(GNParameter.create_string("go_to_name", "Cue name to jump to",
		"Go To Name", "Jump to cue by name (empty = disabled)"))
	add_parameter(GNParameter.create_bool("apply_data", true,
		"Apply Data", "When true, applies cue data{} overrides on cue change"))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	# Parse cue table from input 0
	var cue_table: GNTableData = null
	if inputs.size() > 0 and inputs[0] is GNTableData:
		cue_table = inputs[0] as GNTableData
	if cue_table == null or cue_table.num_rows() == 0:
		node_warning = "No cue table connected."
		return _output_empty()

	var num_cues := cue_table.num_rows()

	# Read parameters
	var source_mode: int = get_param_value("source")
	var timeline_ref: String = get_param_value("timeline")
	var go_next: bool = get_param_value("go_next")
	var go_prev: bool = get_param_value("go_prev")
	var go_to_idx: int = get_param_value("go_to")
	var go_to_name: String = get_param_value("go_to_name")
	var apply_data: bool = get_param_value("apply_data")

	# Clear pulse params
	if go_next and parameters.has("go_next"):
		parameters["go_next"].value = false
	if go_prev and parameters.has("go_prev"):
		parameters["go_prev"].value = false

	# Detect rising edge on trigger input (port 1)
	var trigger_edge := false
	var trigger_chop := _get_input_chop(inputs, 1)
	if trigger_chop != null:
		var trig_val: float = trigger_chop.get_value("trigger", -1)
		if trig_val == 0.0:
			# Try first channel if "trigger" doesn't exist
			var ch_names := trigger_chop.get_channel_names()
			if ch_names.size() > 0:
				trig_val = trigger_chop.get_value(ch_names[0], -1)
		if trig_val > 0.5 and _prev_trigger_val <= 0.5:
			trigger_edge = true
		_prev_trigger_val = trig_val

	# Handle explicit jumps
	var new_cue_idx := _active_cue_idx
	if go_to_idx >= 0 and go_to_idx < num_cues:
		new_cue_idx = go_to_idx
		if parameters.has("go_to"):
			parameters["go_to"].value = -1
	elif not go_to_name.is_empty():
		var found := _find_cue_by_name(cue_table, go_to_name)
		if found >= 0:
			new_cue_idx = found
		if parameters.has("go_to_name"):
			parameters["go_to_name"].value = ""
	elif go_next or trigger_edge:
		new_cue_idx = mini(_active_cue_idx + 1, num_cues - 1)
	elif go_prev:
		new_cue_idx = maxi(_active_cue_idx - 1, 0)

	# Timeline auto-advance mode
	if source_mode == CueSource.TIMELINE and new_cue_idx == _active_cue_idx:
		var current_time := _get_timeline_time(timeline_ref)
		new_cue_idx = _find_cue_for_time(cue_table, current_time)

	# Initialize if first cook
	if _active_cue_idx < 0:
		new_cue_idx = 0

	# Handle cue change
	if new_cue_idx != _active_cue_idx and new_cue_idx >= 0 and new_cue_idx < num_cues:
		_active_cue_idx = new_cue_idx
		_cue_start_time = elapsed_time
		_transition_progress = 0.0
		if apply_data:
			_apply_cue_data(cue_table, _active_cue_idx)

	# Compute cue timing
	var cue_elapsed: float = elapsed_time - _cue_start_time
	var cue_dur := _get_cue_float(cue_table, _active_cue_idx, "duration")
	var cue_remaining: float = 0.0
	var cue_progress: float = 0.0
	if cue_dur > 0.0:
		cue_progress = clampf(cue_elapsed / cue_dur, 0.0, 1.0)
		cue_remaining = maxf(cue_dur - cue_elapsed, 0.0)
	else:
		# Indefinite cue
		cue_progress = 0.0
		cue_remaining = 0.0

	# Compute transition progress
	var trans_str := _get_cue_string(cue_table, _active_cue_idx, "transition")
	var trans_duration := _parse_transition_duration(trans_str)
	if trans_duration > 0.0:
		_transition_progress = clampf(cue_elapsed / trans_duration, 0.0, 1.0)
	else:
		_transition_progress = 1.0  # Cut = instant

	# Next cue index
	var next_cue := mini(_active_cue_idx + 1, num_cues - 1)

	# Output channels
	var out := _prepare_output(60.0)
	out.set_single_value("active_cue", float(_active_cue_idx))
	out.set_single_value("cue_progress", cue_progress)
	out.set_single_value("transition", _transition_progress)
	out.set_single_value("next_cue", float(next_cue))
	out.set_single_value("cue_elapsed", cue_elapsed)
	out.set_single_value("cue_remaining", cue_remaining)
	return out


# ═══════════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════════

func _output_empty() -> GNData:
	var out := _prepare_output(60.0)
	out.set_single_value("active_cue", -1.0)
	out.set_single_value("cue_progress", 0.0)
	out.set_single_value("transition", 0.0)
	out.set_single_value("next_cue", 0.0)
	out.set_single_value("cue_elapsed", 0.0)
	out.set_single_value("cue_remaining", 0.0)
	return out


## Gets the current time from a TimelineCHOP reference or falls back to engine time.
func _get_timeline_time(timeline_ref: String) -> float:
	if timeline_ref.is_empty():
		return elapsed_time
	# Look up the referenced node's "time" channel
	var engine := _get_cook_engine()
	if engine == null:
		return elapsed_time
	var tl_node: GNNode = engine.resolve_node(timeline_ref)
	if tl_node == null or tl_node.cached_output == null:
		return elapsed_time
	if tl_node.cached_output is GNChannelData:
		var cd: GNChannelData = tl_node.cached_output as GNChannelData
		return cd.get_value("time", -1)
	return elapsed_time


## Gets a reference to the cook engine (parent node in scene tree).
func _get_cook_engine() -> GNCookEngine:
	var parent := get_parent()
	if parent is GNCookEngine:
		var _ret0 := parent as GNCookEngine
		return _ret0
	return null


## Finds the cue that should be active at the given time (latest cue whose
## start time <= current_time).
func _find_cue_for_time(table: GNTableData, current_time: float) -> int:
	var best_idx := 0
	var best_time := -INF
	for r in range(table.num_rows()):
		var t := _get_cue_float(table, r, "time")
		if t < 0.0:
			continue  # -1 = manual trigger only
		if t <= current_time and t > best_time:
			best_time = t
			best_idx = r
	return best_idx


## Finds a cue by name. Returns -1 if not found.
func _find_cue_by_name(table: GNTableData, cue_name: String) -> int:
	for r in range(table.num_rows()):
		if _get_cue_string(table, r, "name") == cue_name:
			return r
	return -1


## Gets a float value from a cue table cell by column name.
func _get_cue_float(table: GNTableData, row: int, col_name: String) -> float:
	var val := table.cell_by_name(row, col_name)
	if val.is_valid_float():
		return val.to_float()
	return 0.0


## Gets a string value from a cue table cell by column name.
func _get_cue_string(table: GNTableData, row: int, col_name: String) -> String:
	return table.cell_by_name(row, col_name)


## Parses transition string to get duration.  "cut" = 0.0, "fade:1.5" = 1.5.
func _parse_transition_duration(trans: String) -> float:
	if trans.is_empty() or trans == "cut":
		return 0.0
	if trans.begins_with("fade:"):
		var dur_str := trans.substr(5)
		if dur_str.is_valid_float():
			return dur_str.to_float()
	return 0.0


## Applies the JSON data{} payload from a cue row as parameter overrides.
func _apply_cue_data(table: GNTableData, row: int) -> void:
	var json_str := _get_cue_string(table, row, "data")
	if json_str.is_empty() or json_str == "{}":
		return

	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK:
		node_warning = "Cue %d: invalid JSON in data column" % row
		return

	var data: Variant = json.data
	if not data is Dictionary:
		return

	var engine := _get_cook_engine()
	if engine == null:
		return

	for key: String in data:
		var value: Variant = data[key]
		# Key format: "node_id/param_name"
		var slash_pos := key.rfind("/")
		if slash_pos < 0:
			continue
		var node_id := key.substr(0, slash_pos)
		var param_name := key.substr(slash_pos + 1)
		engine.set_par(node_id, param_name, value)
