class_name DepthSkeletonCHOP
extends GNChopBase
## Outputs hardware skeleton tracking data from a depth sensor as CHOP channels.
##
## For each tracked body, outputs channels per joint:
##   body0:joint_name:tx, ty, tz  — position in meters
##   body0:joint_name:rx, ry, rz  — rotation in degrees (from quaternion)
##   body0:joint_name:confidence  — tracking confidence 0–1
##
## Requires a sensor with skeleton capability (e.g. Azure Kinect with Body
## Tracking SDK).  Sensors without skeleton support output nothing — chain
## DepthSensorTOP → PoseDetectCHOP for ML-based fallback.
##
## Requires the gn_ext_depth_sensor GDExtension (GNDepthSensor class).

var _sensor: RefCounted = null
var _last_serial: String = ""
var _last_backend: String = ""

# Capability flag for skeleton (must match C++ enum)
const CAP_SKELETON := 8


func _init() -> void:
	node_type = "depthskeleton"
	time_dependent = true
	node_description = "Hardware skeleton tracking from depth sensor."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "linux"])

func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Skeleton joint channels")

func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("device",
		GNDepthSensorHelper.get_device_menu(), 0, "Device",
		"Connected sensor (First Available = auto-detect)"))
	add_parameter(GNParameter.create_int("max_bodies", 6, 1, 6, "Max Bodies",
		"Maximum number of tracked bodies to output"))
	add_parameter(GNParameter.create_float("min_confidence", 0.0, 0.0, 1.0, 0.01, "Min Confidence",
		"Minimum joint confidence to include (0 = all)"))
	add_parameter(GNParameter.create_string("joint_filter", "*", "Joint Filter",
		"Wildcard pattern for joint names (* = all)"))
	add_parameter(GNParameter.create_int("timeout_ms", 33, 0, 1000, "Timeout",
		"Frame capture timeout in milliseconds"))
	add_parameter(GNParameter.create_bool("active", true, "",
		"Enable / disable tracking"))
	add_parameter(GNParameter.create_pulse("rescan", "Rescan Devices",
		"Re-enumerate connected sensors and refresh the Device dropdown"))


func _pre_cook(_delta: float) -> void:
	if get_param_value("rescan"):
		set_param_value("rescan", false)
		GNDepthSensorHelper.rescan_and_update_param(self)


func _cook(_inputs: Array[GNData]) -> GNData:
	if not GNDepthSensorHelper.is_available():
		GNLogger.warn("DepthSkeletonCHOP", "'%s': gn_ext_depth_sensor not loaded" % id)
		return null

	if not get_param_value("active"):
		return _cached_channel_data

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
			GNLogger.warn("DepthSkeletonCHOP", "'%s': no sensor backends compiled" % id)
			return null
		backend = backends[0]

	if serial != _last_serial or backend != _last_backend:
		_sensor.close_device()
		if not _sensor.open_device(serial, backend):
			GNLogger.warn("DepthSkeletonCHOP", "'%s': failed to open %s device" % [id, backend])
			return null
		_last_serial = serial
		_last_backend = backend

	if not _sensor.is_device_open():
		return null

	# Check skeleton capability
	if not _sensor.has_capability(CAP_SKELETON):
		GNLogger.warn("DepthSkeletonCHOP", "'%s': sensor does not support skeleton tracking" % id)
		return null

	# Capture
	var timeout: int = get_param_value("timeout_ms")
	if not _sensor.capture(timeout):
		return _cached_channel_data

	# Get skeleton data
	var bodies: Array = _sensor.get_skeleton_data()
	if bodies.is_empty():
		return _cached_channel_data

	var max_bodies: int = get_param_value("max_bodies")
	var min_conf: float = get_param_value("min_confidence")
	var joint_filter: String = get_param_value("joint_filter")
	var out := _prepare_output(60.0)

	for b_idx in range(mini(bodies.size(), max_bodies)):
		var body: Dictionary = bodies[b_idx]
		var body_prefix := "body%d" % b_idx
		var joints: Array = body.get("joints", [])

		for joint_dict: Dictionary in joints:
			var joint_name: String = joint_dict.get("name", "unknown")
			var conf: float = joint_dict.get("confidence", 0.0)

			if conf < min_conf:
				continue
			if not _matches_filter(joint_name, joint_filter):
				continue

			var prefix := "%s:%s" % [body_prefix, joint_name]

			# Position (meters)
			out.set_single_value("%s:tx" % prefix, joint_dict.get("x", 0.0))
			out.set_single_value("%s:ty" % prefix, joint_dict.get("y", 0.0))
			out.set_single_value("%s:tz" % prefix, joint_dict.get("z", 0.0))

			# Rotation (quaternion → euler degrees)
			var qx: float = joint_dict.get("qx", 0.0)
			var qy: float = joint_dict.get("qy", 0.0)
			var qz: float = joint_dict.get("qz", 0.0)
			var qw: float = joint_dict.get("qw", 1.0)
			var quat := Quaternion(qx, qy, qz, qw)
			var euler := quat.get_euler()
			out.set_single_value("%s:rx" % prefix, rad_to_deg(euler.x))
			out.set_single_value("%s:ry" % prefix, rad_to_deg(euler.y))
			out.set_single_value("%s:rz" % prefix, rad_to_deg(euler.z))

			# Confidence
			out.set_single_value("%s:confidence" % prefix, conf)

	return out


# ── Helpers ───────────────────────────────────────────────────────────────────

func _ensure_sensor() -> void:
	if _sensor != null:
		return
	_sensor = ClassDB.instantiate(&"GNDepthSensor")
	if _sensor == null:
		GNLogger.error("DepthSkeletonCHOP", "'%s': failed to instantiate GNDepthSensor" % id)

func _matches_filter(name: String, pattern: String) -> bool:
	if pattern == "*" or pattern.is_empty():
		return true
	return name.matchn(pattern)
