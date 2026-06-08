class_name RenameCHOP
extends GNChopBase
## Renames channels from input to new names in the output.
##
## Two modes:
##   **Pattern** — uses GNPattern wildcard matching and capture-based renaming.
##     From: *_old      To: *(0)_new        (foo_old → foo_new)
##     From: chan*       To: tx[1-4]         (sequential rename via expansion)
##     From: ?x          To: ?(0)y            (tx → ty)
##
##   **Manual Rows** — explicit from→to pairs (1–32 rows).
##     Each row has a **fromN** (source channel name) and **toN** (target name).
## Channels not matched by any rule pass through with their original name.
## Channels not matched by any row pass through with their original name.
## Empty **from** or **to** fields are skipped.

## Tracks the last-applied row count so we only rebuild when it changes.
var _last_count: int = -1


func _init() -> void:
	node_type = "rename"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Input channels", "In")
	add_output("out", GNFamily.Type.CHOP, "Renamed channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Pattern", "Manual Rows"]),
		0, "Mode", "Pattern uses wildcards and capture; Manual Rows uses explicit from/to pairs"))

	# ── Pattern mode params ──
	add_parameter(GNParameter.create_string("from_pattern", "*",
		"From Pattern", "Wildcard pattern to match channels (see PATTERNS.md)"))
	add_parameter(GNParameter.create_string("to_pattern", "*",
		"To Pattern", "Replacement pattern with *(0), ?(0) captures or [1-N] expansion"))
	parameters["from_pattern"].visibility_rule = {"param": "mode", "values": [0]}
	parameters["to_pattern"].visibility_rule = {"param": "mode", "values": [0]}

	# ── Manual Rows mode params ──
	add_parameter(GNParameter.create_int("renames", 1, 1, 32,
		"Renames", "Number of rename rows"))
	parameters["renames"].visibility_rule = {"param": "mode", "values": [1]}
	_rebuild_rename_slots(1)


# ═══════════════════════════════════════════════════════════════════════════════
# Dynamic Slot Management
# ═══════════════════════════════════════════════════════════════════════════════

## Adds or removes fromN / toN parameter pairs to match [param target_count].
## Preserves existing slots when growing.
func _rebuild_rename_slots(target_count: int) -> void:
	target_count = clampi(target_count, 1, 32)
	if target_count == _last_count:
		return

	# Remove slots that exceed the new count
	if _last_count > 0:
		for i in range(target_count, _last_count):
			parameters.erase("from%d" % i)
			parameters.erase("to%d" % i)

	# Add slots that don't exist yet
	for i in range(target_count):
		var from_key := "from%d" % i
		var to_key := "to%d" % i
		var grp := "rename%d" % i
		if not parameters.has(from_key):
			var p_from := GNParameter.create_string(from_key,
				"", "From %d" % i,
				"Source channel name for rename row %d" % i)
			p_from.display_group = grp
			add_parameter(p_from)
		if not parameters.has(to_key):
			var p_to := GNParameter.create_string(to_key,
				"", "To %d" % i,
				"Target channel name for rename row %d" % i)
			p_to.display_group = grp
			add_parameter(p_to)

	_last_count = target_count


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization
# ═══════════════════════════════════════════════════════════════════════════════

## Restores dynamic row count before super restores parameter values,
## so all fromN / toN params exist before [method GNNode.from_dict] loads them.
func from_dict(d: Dictionary) -> void:
	if d.has("parameters") and d["parameters"].has("renames"):
		var saved_data: Dictionary = d["parameters"]["renames"]
		var saved_count: int = int(saved_data.get("value", 1))
		_rebuild_rename_slots(saved_count)
	super.from_dict(d)


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	var in_data: GNChannelData = _get_input_chop(inputs, 0)
	if in_data == null:
		GNLogger.warn("RenameCHOP", "'%s' — no valid input" % id)
		return null

	var mode: int = get_param_value("mode")

	if mode == 0:
		return _cook_pattern(in_data)
	else:
		return _cook_manual(in_data)


## Pattern mode: wildcard match + capture-based replace via GNPattern.
func _cook_pattern(in_data: GNChannelData) -> GNData:
	var from_pat: String = get_param_value("from_pattern").strip_edges()
	var to_pat: String = get_param_value("to_pattern").strip_edges()

	var out := _prepare_output(in_data.sample_rate)

	if from_pat.is_empty() or to_pat.is_empty():
		# Pass-through
		for ch_name in in_data.channels:
			out.set_channel(ch_name, in_data.channels[ch_name])
		return out

	var all_names := PackedStringArray()
	for ch_name in in_data.channels:
		all_names.append(ch_name)

	var rename_map := GNPattern.rename_batch(all_names, from_pat, to_pat)

	for ch_name in in_data.channels:
		var out_name: String = rename_map.get(ch_name, ch_name)
		out.set_channel(out_name, in_data.channels[ch_name])

	return out


## Manual Rows mode: explicit from→to pairs (legacy behaviour).
func _cook_manual(in_data: GNChannelData) -> GNData:
	var row_count: int = get_param_value("renames")

	# Dynamic slot rebuild when user changes count
	if row_count != _last_count:
		_rebuild_rename_slots(row_count)
		parameters_changed.emit(id)

	# Build the rename mapping: source_name → target_name
	var rename_map: Dictionary = {}
	for i in range(row_count):
		var from_name: String = get_param_value("from%d" % i).strip_edges()
		var to_name: String = get_param_value("to%d" % i).strip_edges()
		if not from_name.is_empty() and not to_name.is_empty():
			rename_map[from_name] = to_name

	var out := _prepare_output(in_data.sample_rate)

	# Copy all channels, applying renames where matched
	for ch_name in in_data.channels:
		var out_name: String = rename_map.get(ch_name, ch_name)
		out.set_channel(out_name, in_data.channels[ch_name])

	return out
