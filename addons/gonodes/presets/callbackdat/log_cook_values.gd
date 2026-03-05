# Runs after the target node finishes cooking.
# Variables: target, event ("cook"), event_param (null)

func cook():
	var data = target.get_output_data(0)
	if data and data.has_method("get_channel_names"):
		for ch in data.get_channel_names():
			print("[cook] %s = %.4f" % [ch, data.get_value(ch)])
