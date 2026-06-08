class_name EnginesCOMP
extends GNCompBase
## Cook throttle — controls how often the upstream subtree updates.
##
## Useful for decoupling expensive upstream operators (particle sims,
## L-systems, complex geometry) from downstream consumers that only need
## periodic updates rather than every-frame recooks.
##
## Modes:
##   Live      — pass-through, updates every frame (same as NullCOMP).
##   Snapshot  — freeze on current upstream value; only update when the
##               "snap" parameter is pulsed.
##   Interval  — update every N frames, returning stale data in between.
##
## Note: In Snapshot and Interval modes the operator holds a reference to
## the upstream's most recently cached output.  The upstream subtree still
## cooks every frame (driven by other downstream consumers or time_dependent
## flags); EnginesCOMP simply chooses whether to propagate the new value.

var _cached_data: GNData = null
var _frame_count: int    = 0


func _init() -> void:
	node_type     = "engines"
	time_dependent = true


func _init_ports() -> void:
	add_input("in",  GNFamily.Type.COMP, false, "Upstream component", "In")
	add_output("out", GNFamily.Type.COMP, "Pass-through or cached output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Live", "Snapshot", "Interval"]),
		0, "Mode",
		"Live = every frame · Snapshot = only on snap pulse · Interval = every N frames"))
	add_parameter(GNParameter.create_bool("snap", false,
		"Snap", "Pulse to capture the current upstream value (Snapshot mode only)"))
	add_parameter(GNParameter.create_int("interval", 4, 1, 600,
		"Interval (frames)", "Re-cook upstream every N frames (Interval mode)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var upstream: GNData = inputs[0] if inputs.size() > 0 else null
	var mode: int = get_param_value("mode")

	match mode:
		0:  # Live — always propagate upstream value.
			_cached_data = upstream

		1:  # Snapshot — update only when snap is pulsed.
			if get_param_value("snap") or _cached_data == null:
				_cached_data = upstream

		2:  # Interval — update every N frames.
			var interval: int = maxi(1, get_param_value("interval"))
			_frame_count += 1
			if _cached_data == null or _frame_count >= interval:
				_cached_data = upstream
				_frame_count = 0

	return _cached_data
