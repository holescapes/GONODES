class_name RampCHOPNative
extends GNChopBase
## Native-accelerated ramp curve sampling — delegates to GNNativeRampChop (C++).

var _processor: RefCounted = null
var _last_count: int = -1


func _init() -> void:
	node_type = "ramp_native"
	if ClassDB.class_exists("GNNativeRampChop"):
		_processor = ClassDB.instantiate("GNNativeRampChop")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Ramp channel data")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("samples", 1, 1, 4096,
		"Samples", "Number of evaluation points per channel"))
	add_parameter(GNParameter.create_int("count", 2, 1, 16,
		"Count", "Number of ramp slots"))
	_rebuild_ramp_slots(2)


func _rebuild_ramp_slots(target_count: int) -> void:
	target_count = clampi(target_count, 1, 16)
	if target_count == _last_count:
		return
	if _last_count > 0:
		for i in range(target_count, _last_count):
			parameters.erase("name%d" % i)
			parameters.erase("ramp%d" % i)
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


func from_dict(d: Dictionary) -> void:
	if d.has("parameters") and d["parameters"].has("count"):
		var saved_count_data: Dictionary = d["parameters"]["count"]
		var saved_count: int = int(saved_count_data.get("value", 2))
		_rebuild_ramp_slots(saved_count)
	super.from_dict(d)


func _cook(_inputs: Array[GNData]) -> GNData:
	var sample_count: int = maxi(get_param_value("samples"), 1)
	var slot_count: int = get_param_value("count")

	if slot_count != _last_count:
		_rebuild_ramp_slots(slot_count)
		parameters_changed.emit(id)

	var out := _prepare_output(60.0)

	for i in range(slot_count):
		var ch_name: String = get_param_value("name%d" % i)
		if ch_name.is_empty():
			continue

		var ramp_keys: Array = get_param_value("ramp%d" % i)

		if _processor and not ramp_keys.is_empty():
			# Extract key data into flat arrays for C++
			var positions := PackedFloat32Array()
			var values := PackedFloat32Array()
			var left_tangents := PackedFloat32Array()
			var right_tangents := PackedFloat32Array()
			positions.resize(ramp_keys.size())
			values.resize(ramp_keys.size())
			left_tangents.resize(ramp_keys.size())
			right_tangents.resize(ramp_keys.size())
			for k in range(ramp_keys.size()):
				var key: Dictionary = ramp_keys[k]
				positions[k] = float(key.get("pos", 0.0))
				values[k] = float(key.get("value", 0.0))
				left_tangents[k] = float(key.get("left_tangent", 0.0))
				right_tangents[k] = float(key.get("right_tangent", 0.0))

			out.set_channel(ch_name, _processor.evaluate_ramp(
				positions, values, left_tangents, right_tangents, sample_count))
		else:
			# Fallback: GDScript evaluation
			var samples := PackedFloat32Array()
			samples.resize(sample_count)
			if sample_count == 1:
				samples[0] = GNParameter.sample_ramp(ramp_keys, 1.0)
			else:
				for s in range(sample_count):
					var t: float = float(s) / float(sample_count - 1)
					samples[s] = GNParameter.sample_ramp(ramp_keys, t)
			out.set_channel(ch_name, samples)

	return out
