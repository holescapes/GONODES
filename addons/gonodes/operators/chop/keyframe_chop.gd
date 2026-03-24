class_name KeyframeCHOP
extends GNChopBase
## Keyframe animation curve → CHOP channels.
##
## Each slot defines a named channel with a **ramp** curve (keypoints +
## tangents).  The curve is sampled at the current [member elapsed_time]
## mapped into a user-defined time range ([b]start[/b]–[b]end[/b]).
## Outside the range the **extend** mode determines behaviour (Hold,
## Cycle, Mirror, Slope).
##
## This is the GONODES equivalent of TouchDesigner's Keyframe CHOP —
## the primary way to author hand-tuned parameter animations.

enum ExtendMode { HOLD, CYCLE, MIRROR, SLOPE }

var _last_count: int = -1


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "keyframe"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Animated channel data")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("start", 0.0, null, null, 0.01,
		"Start", "Start time (seconds) of the animation range"))
	add_parameter(GNParameter.create_float("end", 4.0, 0.001, null, 0.01,
		"End", "End time (seconds) of the animation range"))
	add_parameter(GNParameter.create_enum("extend", ExtendMode.keys(),
		0, "Extend", "Behaviour outside start–end range"))
	add_parameter(GNParameter.create_int("count", 1, 1, 16,
		"Count", "Number of channel slots"))
	_rebuild_slots(1)


# ═══════════════════════════════════════════════════════════════════════════════
# Dynamic Slot Management
# ═══════════════════════════════════════════════════════════════════════════════

func _rebuild_slots(target: int) -> void:
	target = clampi(target, 1, 16)
	if target == _last_count:
		return
	if _last_count > 0:
		for i in range(target, _last_count):
			parameters.erase("name%d" % i)
			parameters.erase("curve%d" % i)
	for i in range(target):
		var nk := "name%d" % i
		var ck := "curve%d" % i
		if not parameters.has(nk):
			add_parameter(GNParameter.create_string(nk,
				"anim%d" % i, "Name %d" % i,
				"Channel name for slot %d" % i))
		if not parameters.has(ck):
			add_parameter(GNParameter.create_ramp(ck, [],
				"Curve %d" % i,
				"Keyframe curve for slot %d" % i))
	_last_count = target


func from_dict(d: Dictionary) -> void:
	if d.has("parameters") and d["parameters"].has("count"):
		var c: int = int(d["parameters"]["count"].get("value", 1))
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

	var t_start: float = get_param_value("start")
	var t_end: float = get_param_value("end")
	var extend: int = get_param_value("extend")
	var duration := maxf(t_end - t_start, 0.001)

	# Map elapsed_time into [0,1] normalized position within the range
	var raw_t := (elapsed_time - t_start) / duration
	var norm_t := _apply_extend(raw_t, extend)

	var out := _prepare_output(60.0)

	for i in range(slot_count):
		var ch_name: String = get_param_value("name%d" % i)
		if ch_name.is_empty():
			continue
		var keys: Array = get_param_value("curve%d" % i)
		var value := GNParameter.sample_ramp(keys, norm_t)
		out.set_single_value(ch_name, value)

	return out


## Maps a raw normalised time into [0,1] according to the extend mode.
func _apply_extend(t: float, mode: int) -> float:
	if t >= 0.0 and t <= 1.0:
		return t
	match mode:
		ExtendMode.HOLD:
			return clampf(t, 0.0, 1.0)
		ExtendMode.CYCLE:
			return fmod(t, 1.0) if t >= 0.0 else 1.0 + fmod(t, 1.0)
		ExtendMode.MIRROR:
			var period := fmod(absf(t), 2.0)
			return period if period <= 1.0 else 2.0 - period
		ExtendMode.SLOPE:
			return t  # linear extrapolation — ramp naturally extrapolates
	return clampf(t, 0.0, 1.0)
