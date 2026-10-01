class_name SystemDAT
extends GNDatBase
## Outputs detailed system information as a DAT table.
## Includes OS, CPU, GPU, memory, display, and Godot engine details.
## Extends InfoDAT with more hardware-specific information.


func _init() -> void:
	node_type = "system"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "System information table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("hardware", true,
		"Hardware", "Include CPU/GPU hardware details"))
	add_parameter(GNParameter.create_bool("memory", true,
		"Memory", "Include memory usage details"))
	add_parameter(GNParameter.create_bool("display", true,
		"Display", "Include display/screen information"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var show_hw: bool = get_param_value("hardware")
	var show_mem: bool = get_param_value("memory")
	var show_disp: bool = get_param_value("display")

	var table := _prepare_table()
	table.is_table = true
	table.has_header = true
	table.set_headers(PackedStringArray(["category", "property", "value"]))

	# OS
	table.append_row(PackedStringArray(["OS", "name", OS.get_name()]))
	table.append_row(PackedStringArray(["OS", "version", OS.get_version()]))
	table.append_row(PackedStringArray(["OS", "locale", OS.get_locale()]))

	# Engine
	table.append_row(PackedStringArray(["Engine", "version", Engine.get_version_info().get("string", "unknown")]))
	table.append_row(PackedStringArray(["Engine", "fps", "%.1f" % Engine.get_frames_per_second()]))
	table.append_row(PackedStringArray(["Engine", "frame", str(Engine.get_process_frames())]))

	# Hardware
	if show_hw:
		table.append_row(PackedStringArray(["CPU", "name", OS.get_processor_name()]))
		table.append_row(PackedStringArray(["CPU", "cores", str(OS.get_processor_count())]))

		# GPU info via RenderingServer
		var device_name: String = RenderingServer.get_video_adapter_name()
		var vendor: String = RenderingServer.get_video_adapter_vendor()
		var api: String = RenderingServer.get_video_adapter_api_version()
		table.append_row(PackedStringArray(["GPU", "device", device_name]))
		table.append_row(PackedStringArray(["GPU", "vendor", vendor]))
		table.append_row(PackedStringArray(["GPU", "api_version", api]))

	# Memory
	if show_mem:
		table.append_row(PackedStringArray(["Memory", "static", _format_bytes(OS.get_static_memory_usage())]))
		table.append_row(PackedStringArray(["Memory", "static_bytes", str(OS.get_static_memory_usage())]))
		table.append_row(PackedStringArray(["Memory", "static_peak", _format_bytes(OS.get_static_memory_peak_usage())]))
		table.append_row(PackedStringArray(["Memory", "static_peak_bytes", str(OS.get_static_memory_peak_usage())]))

	# Display
	if show_disp:
		var screen_count: int = DisplayServer.get_screen_count()
		table.append_row(PackedStringArray(["Display", "screen_count", str(screen_count)]))
		for i in range(screen_count):
			var size: Vector2i = DisplayServer.screen_get_size(i)
			var dpi: int = DisplayServer.screen_get_dpi(i)
			table.append_row(PackedStringArray(["Display", "screen_%d_size" % i, "%dx%d" % [size.x, size.y]]))
			table.append_row(PackedStringArray(["Display", "screen_%d_width" % i, str(size.x)]))
			table.append_row(PackedStringArray(["Display", "screen_%d_height" % i, str(size.y)]))
			table.append_row(PackedStringArray(["Display", "screen_%d_dpi" % i, str(dpi)]))

	return table


func _format_bytes(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes
	elif bytes < 1048576:
		return "%.1f KB" % (bytes / 1024.0)
	elif bytes < 1073741824:
		return "%.1f MB" % (bytes / 1048576.0)
	else:
		return "%.2f GB" % (bytes / 1073741824.0)
