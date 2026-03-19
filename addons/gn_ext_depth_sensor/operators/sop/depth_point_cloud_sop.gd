class_name DepthPointCloudSOP
extends GNSopBase
## Generates a dense 3D point cloud mesh from a depth sensor's native
## point cloud data, with optional per-point color from the color camera.
##
## Outputs a POINTS primitive mesh — render with PointCloudRenderTOP or
## a custom particle material for best visual results.
##
## Requires the gn_ext_depth_sensor GDExtension (GNDepthSensor class).

var _sensor: RefCounted = null
var _last_serial: String = ""
var _last_backend: String = ""

# Capability flags (must match C++ enum)
const CAP_POINT_CLOUD := 16
const CAP_COLOR := 2


func _init() -> void:
	node_type = "depthpointcloud"
	time_dependent = true
	node_description = "Dense 3D point cloud from depth sensor."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "linux"])

func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Point cloud mesh")

func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("device",
		GNDepthSensorHelper.get_device_menu(), 0, "Device",
		"Connected sensor (First Available = auto-detect)"))
	add_parameter(GNParameter.create_bool("use_color", true, "Color",
		"Use color camera data for per-point color (Cd attribute)"))
	add_parameter(GNParameter.create_int("skip", 1, 1, 16, "Skip",
		"Sample every Nth point (1 = all, 4 = 1/4 density)"))
	add_parameter(GNParameter.create_float("max_depth", 5.0, 0.1, 20.0, 0.1, "Max Depth (m)",
		"Discard points beyond this distance in meters"))
	add_parameter(GNParameter.create_int("timeout_ms", 33, 0, 1000, "Timeout",
		"Frame capture timeout in milliseconds"))
	add_parameter(GNParameter.create_bool("active", true, "",
		"Enable / disable capture"))
	add_parameter(GNParameter.create_pulse("rescan", "Rescan Devices",
		"Re-enumerate connected sensors and refresh the Device dropdown"))


func _pre_cook(_delta: float) -> void:
	if get_param_value("rescan"):
		set_param_value("rescan", false)
		GNDepthSensorHelper.rescan_and_update_param(self)


func _cook(_inputs: Array[GNData]) -> GNData:
	if not GNDepthSensorHelper.is_available():
		GNLogger.warn("DepthPointCloudSOP", "'%s': gn_ext_depth_sensor not loaded" % id)
		return null

	if not get_param_value("active"):
		return _cached_geo

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
			GNLogger.warn("DepthPointCloudSOP", "'%s': no sensor backends compiled" % id)
			return null
		backend = backends[0]

	if serial != _last_serial or backend != _last_backend:
		_sensor.close_device()
		if not _sensor.open_device(serial, backend):
			GNLogger.warn("DepthPointCloudSOP", "'%s': failed to open %s device" % [id, backend])
			return null
		_last_serial = serial
		_last_backend = backend

	if not _sensor.is_device_open():
		return null

	if not _sensor.has_capability(CAP_POINT_CLOUD):
		GNLogger.warn("DepthPointCloudSOP", "'%s': sensor does not support point cloud" % id)
		return null

	# Capture
	var timeout: int = get_param_value("timeout_ms")
	if not _sensor.capture(timeout):
		return _cached_geo

	# Get point cloud data
	var positions: PackedFloat32Array = _sensor.get_point_cloud_positions()
	if positions.is_empty():
		return _cached_geo

	var use_color: bool = get_param_value("use_color") and _sensor.has_capability(CAP_COLOR)
	var colors: PackedByteArray
	if use_color:
		colors = _sensor.get_point_cloud_colors()

	var skip: int = maxi(1, get_param_value("skip"))
	var max_depth: float = get_param_value("max_depth")

	# Build point cloud mesh
	var geo := _prepare_geo()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)

	var point_count: int = positions.size() / 3
	var has_colors: bool = use_color and colors.size() >= point_count * 4

	for i in range(0, point_count, skip):
		var x: float = positions[i * 3]
		var y: float = positions[i * 3 + 1]
		var z: float = positions[i * 3 + 2]

		# Skip zero-depth and beyond max range
		if absf(z) < 0.001 or absf(z) > max_depth:
			continue

		if has_colors:
			var r: float = colors[i * 4] / 255.0
			var g: float = colors[i * 4 + 1] / 255.0
			var b: float = colors[i * 4 + 2] / 255.0
			st.set_color(Color(r, g, b, 1.0))

		st.set_normal(Vector3(0, 0, -1))
		st.add_vertex(Vector3(x, -y, -z))  # Flip Y and Z for Godot coordinate system

	var arr_mesh := ArrayMesh.new()
	st.commit(arr_mesh)
	geo.set_mesh(arr_mesh)

	return geo


# ── Helpers ───────────────────────────────────────────────────────────────────

func _ensure_sensor() -> void:
	if _sensor != null:
		return
	_sensor = ClassDB.instantiate(&"GNDepthSensor")
	if _sensor == null:
		GNLogger.error("DepthPointCloudSOP", "'%s': failed to instantiate GNDepthSensor" % id)
