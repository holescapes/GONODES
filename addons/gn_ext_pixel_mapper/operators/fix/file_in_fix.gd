class_name FileInFIX
extends GNFixtureBase
## Loads fixture definitions from a JSON file.
##
## Supported formats:
##   GONODES .fixture — {"name":..., "leds":[{"uv_x":f, "uv_y":f}, ...],
##                       "channel_layout":"rgb", "dmx_start":N}
##
## The file path supports project:// and absolute paths.


func _init() -> void:
	super._init()
	node_type = "file_in_fix"
	node_description = "Loads a fixture definition from a JSON file. Supports GONODES .fixture format."


func _init_ports() -> void:
	add_output("out", GNFixtureBase.FIX_FAMILY, "Fixture layout loaded from file")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("file", "",
		"File", "Path to a .fixture JSON file."))
	add_parameter(GNParameter.create_enum("channel_layout",
		PackedStringArray(["From File", "RGB", "RGBW", "R", "G", "B", "W"]), 0,
		"Channel Layout", "'From File' reads layout from the JSON. Others override it."))
	add_parameter(GNParameter.create_int("dmx_start", 0, 0, 32767,
		"DMX Start Override", "Overrides the file's dmx_start when non-zero."))
	add_parameter(GNParameter.create_vector2("sample_extent", Vector2.ZERO,
		"Sample Extent", "UV half-size of the box-filter area per LED. (0,0) = point sample."))


func _cook(_inputs: Array[GNData]) -> GNData:
	var path: String = get_param_value("file")
	if path.is_empty():
		node_warning = "No file path set."
		return null

	var resolved: String = GNResourceLoader.resolve(path, "")
	if resolved.is_empty() or not FileAccess.file_exists(resolved):
		node_warning = "File not found: %s" % path
		return null

	var file := FileAccess.open(resolved, FileAccess.READ)
	if file == null:
		node_warning = "Cannot open file: %s" % path
		return null
	var json_string: String = file.get_as_text()
	file.close()

	var parsed := JSON.new()
	var parse_err: int = parsed.parse(json_string)
	if parse_err != OK:
		node_warning = "JSON parse error at line %d: %s" % [parsed.get_error_line(), parsed.get_error_message()]
		return null

	var doc: Dictionary = parsed.get_data() as Dictionary
	if doc == null:
		node_warning = "JSON root must be a Dictionary."
		return null

	var led_array: Array = doc.get("leds", [])
	if led_array.is_empty():
		node_warning = "No 'leds' array found in file."
		return null

	node_warning = ""
	var out: GNFixtureData = _prepare_output()
	out.fixture_name = doc.get("name", path.get_file().get_basename())
	out.led_count = led_array.size()
	out.led_positions.resize(out.led_count)

	for i in range(led_array.size()):
		var entry: Dictionary = led_array[i] as Dictionary if led_array[i] is Dictionary else {}
		out.led_positions[i] = Vector2(float(entry.get("uv_x", 0.0)), float(entry.get("uv_y", 0.0)))

	# Channel layout — "From File" (0) reads from JSON, others override
	var layout_idx: int = get_param_value("channel_layout")
	if layout_idx == 0:
		out.channel_layout = doc.get("channel_layout", "rgb")
	else:
		out.channel_layout = ["rgb", "rgbw", "r", "g", "b", "w"][layout_idx - 1]
	out.channels_per_led = GNFixtureData.channels_for_layout(out.channel_layout)

	# DMX start — non-zero param overrides file value
	var dmx_override: int = get_param_value("dmx_start")
	out.dmx_start = dmx_override if dmx_override > 0 else int(doc.get("dmx_start", 0))
	out.sample_extent = get_param_value("sample_extent")

	return out
