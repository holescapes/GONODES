class_name ChannelCHOP
extends GNChopBase
## Create named channels directly from parameter values.
##
## Each slot has a name and a float value (supports expressions).
## This is the simplest way to turn parameter-level expressions into
## CHOP channel data for downstream operators.
##
## TouchDesigner equivalent: Channel CHOP.

var _last_count: int = -1


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "channel"
	node_description = "Named channels from parameter values."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Channel data output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("count", 3, 1, 32,
		"Count", "Number of channel slots"))
	_rebuild_slots(3)


func _rebuild_slots(target: int) -> void:
	target = clampi(target, 1, 32)
	if target == _last_count:
		return
	if _last_count > 0:
		for i in range(target, _last_count):
			parameters.erase("name%d" % i)
			parameters.erase("value%d" % i)
	for i in range(target):
		var nk := "name%d" % i
		var vk := "value%d" % i
		if not parameters.has(nk):
			add_parameter(GNParameter.create_string(nk,
				"chan%d" % i, "Name %d" % i,
				"Channel name for slot %d" % i))
		if not parameters.has(vk):
			add_parameter(GNParameter.create_float(vk,
				0.0, null, null, 0.01,
				"Value %d" % i,
				"Channel value for slot %d (expression-friendly)" % i))
	_last_count = target


func from_dict(d: Dictionary) -> void:
	if d.has("parameters") and d["parameters"].has("count"):
		var c: int = int(d["parameters"]["count"].get("value", 3))
		_rebuild_slots(c)
	super.from_dict(d)


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(_inputs: Array[GNData]) -> GNData:
	var slot_count: int = get_param_value("count")
	if slot_count != _last_count:
		_rebuild_slots(slot_count)
		parameters_changed.emit(id)

	var out := _prepare_output(60.0)

	for i in range(slot_count):
		var ch_name: String = get_param_value("name%d" % i)
		if ch_name.is_empty():
			continue
		var value: float = get_param_value("value%d" % i)
		out.set_single_value(ch_name, value)

	return out
