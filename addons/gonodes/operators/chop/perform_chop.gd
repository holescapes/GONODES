class_name PerformCHOP
extends GNChopBase
## Outputs system performance metrics as CHOP channels.
## Similar to TouchDesigner's Perform CHOP — provides FPS, frame time,
## memory usage, cook time, and other engine stats.

func _init() -> void:
	node_type = "perform"
	node_description = "System performance metrics as CHOP channels."
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Performance channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("fps", true, "FPS", "Output frames per second"))
	add_parameter(GNParameter.create_bool("frame_time", true, "Frame Time",
		"Output frame time in milliseconds"))
	add_parameter(GNParameter.create_bool("frame_count", true, "Frame Count",
		"Output total frames drawn"))
	add_parameter(GNParameter.create_bool("memory", true, "Memory",
		"Output static memory usage in MB"))
	add_parameter(GNParameter.create_bool("gpu_time", false, "GPU Time",
		"Output last GPU frame time if available"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = 60.0

	if get_param_value("fps"):
		_cached_channel_data.set_single_value("fps", Engine.get_frames_per_second())

	if get_param_value("frame_time"):
		var ft: float = 1000.0 / maxf(Engine.get_frames_per_second(), 1.0)
		_cached_channel_data.set_single_value("frame_time_ms", ft)

	if get_param_value("frame_count"):
		_cached_channel_data.set_single_value("frame_count",
			float(Engine.get_frames_drawn()))

	if get_param_value("memory"):
		var mem_bytes: int = OS.get_static_memory_usage()
		_cached_channel_data.set_single_value("memory_mb",
			mem_bytes / (1024.0 * 1024.0))

	if get_param_value("gpu_time"):
		_cached_channel_data.set_single_value("gpu_time_ms",
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)

	return _cached_channel_data
