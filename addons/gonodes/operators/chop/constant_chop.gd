class_name ConstantCHOP
extends GNChopBase
## Outputs one or more channels with constant (static) values.
## The **count** parameter controls how many channel slots exist (1–32).
## Each slot has a **nameN** (channel name) and **valueN** (constant value).
## Empty names are skipped.  Changing **count** at runtime dynamically
## adds/removes parameter pairs and triggers an inspector rebuild.

## Tracks the last-applied slot count so we only rebuild when it changes.
var _last_count: int = -1


func _init() -> void:
	node_type = "constant"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Channel data output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("count", 1, 1, 32,
		"Count", "Number of channel slots"))
	_rebuild_channel_slots(1)


func _on_parameter_changed(param_name: String, _new_value: Variant) -> void:
	if param_name == "count":
		_rebuild_channel_slots(int(_new_value))
	super._on_parameter_changed(param_name, _new_value)


# ═══════════════════════════════════════════════════════════════════════════════
# Dynamic Slot Management
# ═══════════════════════════════════════════════════════════════════════════════

## Adds or removes nameN / valueN parameter pairs to match [param target_count].
## Preserves existing slots when growing.
func _rebuild_channel_slots(target_count: int) -> void:
	target_count = clampi(target_count, 1, 32)
	if target_count == _last_count:
		return

	# Remove slots that exceed the new count
	if _last_count > 0:
		for i in range(target_count, _last_count):
			parameters.erase("name%d" % i)
			parameters.erase("value%d" % i)

	# Add slots that don't exist yet
	for i in range(target_count):
		var name_key := "name%d" % i
		var value_key := "value%d" % i
		if not parameters.has(name_key):
			var default_name := "chan%d" % (i + 1) if i == 0 else ""
			add_parameter(GNParameter.create_string(name_key,
				default_name, "Name %d" % i,
				"Channel name for slot %d (empty = skip)" % i))
		if not parameters.has(value_key):
			add_parameter(GNParameter.create_float(value_key,
				0.0, null, null, 0.01,
				"Value %d" % i,
				"Constant value for channel %d" % i))

	_last_count = target_count


# ═══════════════════════════════════════════════════════════════════════════════
# Serialization
# ═══════════════════════════════════════════════════════════════════════════════

## Restores dynamic slot count before super restores parameter values,
## so all nameN / valueN params exist before [method GNNode.from_dict] loads them.
func from_dict(d: Dictionary) -> void:
	if d.has("parameters") and d["parameters"].has("count"):
		var saved_count_data: Dictionary = d["parameters"]["count"]
		var saved_count: int = int(saved_count_data.get("value", 1))
		_rebuild_channel_slots(saved_count)
	super.from_dict(d)


func _cook(_inputs: Array[GNData]) -> GNData:
	var slot_count: int = get_param_value("count")

	# Dynamic slot rebuild when user changes count
	if slot_count != _last_count:
		_rebuild_channel_slots(slot_count)
		parameters_changed.emit(id)

	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = 60.0

	for i in range(slot_count):
		var ch_name: String = get_param_value("name%d" % i)
		if ch_name.is_empty():
			continue
		var ch_val: float = get_param_value("value%d" % i)
		_cached_channel_data.set_single_value(ch_name, ch_val)

	return _cached_channel_data
