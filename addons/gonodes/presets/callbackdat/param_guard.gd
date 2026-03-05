# Clamp any numeric parameter to a safe range whenever it changes.
# Variables: target, event ("value_change"), event_param (param name)

func cook():
	if event_param == null:
		return
	var val = target.get_param_value(event_param)
	if val is float:
		var clamped := clampf(val, -100.0, 100.0)
		if clamped != val:
			set_par(target.id, event_param, clamped)
			print("[guard] Clamped %s.%s: %.2f → %.2f" % [target.id, event_param, val, clamped])
