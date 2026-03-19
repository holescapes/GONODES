class_name DepthSensorTOP
extends GNTopBase
## Outputs image streams from a depth sensor: depth, color, IR, or player index.
##
## Supports all compiled depth sensor backends via the unified GNDepthSensor
## interface.  The Device parameter selects which sensor to use (or auto-
## detects the first available).  The Stream parameter selects the image.
## If the sensor doesn't support the requested stream, the output is black.
##
## Requires the gn_ext_depth_sensor GDExtension (GNDepthSensor class).

var _sensor: RefCounted = null
var _last_serial: String = ""
var _last_backend: String = ""

# Stream mode enum indices
const STREAM_DEPTH := 0
const STREAM_COLOR := 1
const STREAM_IR := 2
const STREAM_PLAYER_INDEX := 3


func _init() -> void:
	node_type = "depthsensor"
	time_dependent = true
	node_description = "Depth sensor image streams (depth/color/IR/player index)."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "linux"])

func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Sensor image")

func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("device",
		GNDepthSensorHelper.get_device_menu(), 0, "Device",
		"Connected sensor (First Available = auto-detect)"))
	add_parameter(GNParameter.create_enum("stream",
		PackedStringArray(["Depth", "Color", "IR", "Player Index"]), 0, "Stream",
		"Which image stream to output"))
	add_parameter(GNParameter.create_int("max_depth_mm", 5000, 500, 20000, "Max Depth (mm)",
		"Maximum depth range for depth visualization normalization"))
	add_parameter(GNParameter.create_int("timeout_ms", 33, 0, 1000, "Timeout",
		"Frame capture timeout in milliseconds"))
	add_parameter(GNParameter.create_bool("active", true, "",
		"Enable / disable sensor capture"))
	add_parameter(GNParameter.create_pulse("rescan", "Rescan Devices",
		"Re-enumerate connected sensors and refresh the Device dropdown"))


func _pre_cook(_delta: float) -> void:
	if get_param_value("rescan"):
		set_param_value("rescan", false)
		GNDepthSensorHelper.rescan_and_update_param(self)


func _cook(_inputs: Array[GNData]) -> GNData:
	if not GNDepthSensorHelper.is_available():
		GNLogger.warn("DepthSensorTOP", "'%s': gn_ext_depth_sensor GDExtension not loaded" % id)
		return null

	if not get_param_value("active"):
		return _cached_tex_data

	_ensure_sensor()
	if _sensor == null:
		return null

	# Resolve device from dropdown
	var dev := GNDepthSensorHelper.get_device_at(get_param_value("device"))
	var serial: String = dev.get("serial", "")
	var backend: String = dev.get("backend", "")

	# "First Available" — use first compiled backend
	if backend.is_empty():
		var backends := GNDepthSensorHelper.get_backends()
		if backends.is_empty():
			GNLogger.warn("DepthSensorTOP", "'%s': no sensor backends compiled" % id)
			return null
		backend = backends[0]

	if serial != _last_serial or backend != _last_backend:
		_sensor.close_device()
		if not _sensor.open_device(serial, backend):
			GNLogger.warn("DepthSensorTOP", "'%s': failed to open %s device '%s'" % [id, backend, serial])
			return null
		_last_serial = serial
		_last_backend = backend

	if not _sensor.is_device_open():
		return null

	# Capture frame
	var timeout: int = get_param_value("timeout_ms")
	if not _sensor.capture(timeout):
		return _cached_tex_data

	# Get the requested stream
	var stream_mode: int = get_param_value("stream")
	var rgba: PackedByteArray
	var w: int = 0
	var h: int = 0

	match stream_mode:
		STREAM_DEPTH:
			var max_mm: int = get_param_value("max_depth_mm")
			rgba = _sensor.get_depth_rgba(max_mm)
			w = _sensor.get_depth_width()
			h = _sensor.get_depth_height()
		STREAM_COLOR:
			rgba = _sensor.get_color_rgba()
			w = _sensor.get_color_width()
			h = _sensor.get_color_height()
		STREAM_IR:
			rgba = _sensor.get_ir_rgba()
			w = _sensor.get_ir_width()
			h = _sensor.get_ir_height()
		STREAM_PLAYER_INDEX:
			rgba = _sensor.get_player_index_rgba()
			# Player index uses depth dimensions
			w = _sensor.get_depth_width()
			h = _sensor.get_depth_height()

	if rgba.is_empty() or w <= 0 or h <= 0:
		return _cached_tex_data

	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba)
	var tex := ImageTexture.create_from_image(img)

	if _cached_tex_data == null:
		_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = tex
	_cached_tex_data.resolution = Vector2i(w, h)
	_cached_tex_data.format = Image.FORMAT_RGBA8
	return _cached_tex_data


# ── Helpers ───────────────────────────────────────────────────────────────────

func _ensure_sensor() -> void:
	if _sensor != null:
		return
	_sensor = ClassDB.instantiate(&"GNDepthSensor")
	if _sensor == null:
		GNLogger.error("DepthSensorTOP", "'%s': failed to instantiate GNDepthSensor" % id)
