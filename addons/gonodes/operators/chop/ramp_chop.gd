class_name RampCHOP
extends GNChopBase
## Outputs named channels by sampling user-editable ramp curves.
##
## The **count** parameter controls how many ramp slots exist (1–16).
## Each slot has a **nameN** (channel name) and **rampN** (curve keypoints).
## Empty names are skipped.  The **samples** parameter sets the number of
## evenly-spaced evaluation points per channel (1 = single scalar value,
## which is what [code]chop("ramp1", "falloff")[/code] reads).
##
## Changing **count** at runtime dynamically adds/removes parameter pairs
## and triggers an inspector rebuild via [signal GNNode.parameters_changed].

# ─── Internal bookkeeping ──────────────────────────────────────────────────────

## Tracks the last-applied slot count so we only rebuild when it changes.
var _last_count: int = -1


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "ramp"
	node_description = "Dynamic ramp curves → CHOP channels."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Ramp channel data")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("samples", 1, 1, 4096,
		"Samples", "Number of evaluation points per channel"))
	add_parameter(GNParameter.create_int("count", 2, 1, 16,
		"Count", "Number of ramp slots"))
	_rebuild_ramp_slots(2)


# ═══════════════════════════════════════════════════════════════════════════════
# Dynamic Slot Management
# ═══════════════════════════════════════════════════════════════════════════════

## Adds or removes nameN / rampN parameter pairs to match [param target_count].
## Preserves existing slots when growing.
func _rebuild_ramp_slots(target_count: int) -> void:
	target_count = clampi(target_count, 1, 16)
	if target_count == _last_count:
		return

	# Remove slots that exceed the new count
	if _last_count > 0:
		for i in range(target_count, _last_count):
			parameters.erase("name%d" % i)
			parameters.erase("ramp%d" % i)

	# Add slots that don't exist yet
	for i in range(target_count):
		var name_key := "name%d" % i
		var ramp_key := "ramp%d" % i
		if not parameters.has(name_key):
			add_parameter(GNParameter.create_string(name_key,
				"ramp%d" % i, "Name %d" % i,
				"Channel name for ramp slot %d" % i))
		if not parameters.has(ramp_key):
			add_parameter(GNParameter.create_ramp(ramp_key, [],
				"Ramp %d" % i,
				"Ramp curve for slot %d" % i))

	_last_count = target_count


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization
# ═══════════════════════════════════════════════════════════════════════════════

## Restores dynamic slot count before super restores parameter values,
## so all nameN / rampN params exist before [method GNNode.from_dict] loads them.
func from_dict(d: Dictionary) -> void:
	if d.has("parameters") and d["parameters"].has("count"):
		var saved_count_data: Dictionary = d["parameters"]["count"]
		var saved_count: int = int(saved_count_data.get("value", 2))
		_rebuild_ramp_slots(saved_count)
	super.from_dict(d)


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var sample_count: int = maxi(get_param_value("samples"), 1)
	var slot_count: int = get_param_value("count")

	# Dynamic slot rebuild when user changes count
	if slot_count != _last_count:
		_rebuild_ramp_slots(slot_count)
		parameters_changed.emit(id)

	var out := _prepare_output(60.0)

	for i in range(slot_count):
		var ch_name: String = get_param_value("name%d" % i)
		if ch_name.is_empty():
			continue

		var ramp_keys: Array = get_param_value("ramp%d" % i)
		var samples := PackedFloat32Array()
		samples.resize(sample_count)

		if sample_count == 1:
			# Single-value: evaluate at t=1.0 (end of curve — useful as scalar)
			samples[0] = GNParameter.sample_ramp(ramp_keys, 1.0)
		else:
			for s in range(sample_count):
				var t: float = float(s) / float(sample_count - 1)
				samples[s] = GNParameter.sample_ramp(ramp_keys, t)

		out.set_channel(ch_name, samples)

	return out
