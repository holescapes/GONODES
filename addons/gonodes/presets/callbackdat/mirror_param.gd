# Mirrors a parameter change to another node.
# Variables: target, event ("value_change"), event_param (param name)

func cook():
	if event_param:
		var val = target.get_param_value(event_param)
		set_par("mirror_node", event_param, val)
