class_name FileInFIX
extends GNFixtureBase
## Loads fixture definitions from a JSON file.
##
## Supported formats:
##   GONODES .fixture -- {"name":..., "leds":[{"x":f, "y":f}, ...],
##                        "channel_layout":"rgb", "universe":N, "start_channel":N}
##
## The file path supports project:// and absolute paths.
## Placement on the source image is handled by FixtureSamplerTOP.


func _init() -> void:
	super._init()
	node_type = "file_in_fix"
	node_description = "Loads a fixture definition from a JSON file. Supports GONODES .fixture format."


func _init_ports() -> void:
	add_output("out", GNFixtureBase.FIX_FAMILY, "Fixture layout loaded from file")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("file", "", PackedStringArray(["*.fixture", "*.json"]),
		"File", "Path to a .fixture JSON file."))
	add_parameter(GNParameter.create_enum("channel_layout",
		PackedStringArray(["From File", "RGB", "RGBW", "R", "G", "B", "W"]), 0,
		"Channel Layout", "'From File' reads layout from the JSON. Others override it."))
	add_parameter(GNParameter.create_int("universe", 0, 0, 32767,
		"Universe Override", "Overrides the file's universe when non-zero."))
	add_parameter(GNParameter.create_int("start_channel", 0, 0, 512,
		"Start Channel Override", "Overrides the file's start_channel when non-zero."))


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
		# Support both "x"/"y" (new) and legacy "uv_x"/"uv_y" keys
		var px: float = float(entry.get("x", entry.get("uv_x", 0.0)))
		var py: float = float(entry.get("y", entry.get("uv_y", 0.0)))
		out.led_positions[i] = Vector2(px, py)

	# Channel layout
	var layout_idx: int = get_param_value("channel_layout")
	if layout_idx == 0:
		out.channel_layout = doc.get("channel_layout", "rgb")
	else:
		out.channel_layout = ["rgb", "rgbw", "r", "g", "b", "w"][layout_idx - 1]
	out.channels_per_led = GNFixtureData.channels_for_layout(out.channel_layout)

	# DMX addressing
	var uni_override: int = get_param_value("universe")
	out.universe = uni_override if uni_override > 0 else int(doc.get("universe", 1))
	var ch_override: int = get_param_value("start_channel")
	out.start_channel = ch_override if ch_override > 0 else int(doc.get("start_channel", 1))

	# Detect shape from file or default to custom
	out.shape = StringName(doc.get("shape", "custom"))

	return out
