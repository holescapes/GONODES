# Log every cook with a timestamp — useful for profiling cook frequency.
# Variables: target, event ("cook"), event_param (null)

func cook():
	var data = target.get_output_data(0)
	var summary := "no data"
	if data and data.has_method("get_channel_names"):
		var names := data.get_channel_names()
		summary = "%d channels" % names.size()
	elif data and data.has_method("get_row_count"):
		summary = "%d rows" % data.get_row_count()
	print("[%s] cook #%d: %s" % [target.id, frame, summary])
