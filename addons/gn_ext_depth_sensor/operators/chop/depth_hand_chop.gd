class_name DepthHandCHOP
extends GNChopBase
## Outputs hand and finger tracking data from a depth sensor as CHOP channels.
##
## For each tracked hand, outputs:
##   hand0:palm:tx, ty, tz            — palm position in meters
##   hand0:palm:rx, ry, rz            — palm rotation in degrees
##   hand0:wrist:tx, ty, tz, rx, ry, rz
##   hand0:thumb_metacarpal:tx, ty, tz, rx, ry, rz
##   hand0:thumb_proximal:tx, ty, tz, rx, ry, rz
##   hand0:thumb_intermediate:tx, ty, tz, rx, ry, rz
##   hand0:thumb_distal:tx, ty, tz, rx, ry, rz
##   hand0:thumb_tip:tx, ty, tz, rx, ry, rz
##   ... (same for index, middle, ring, pinky)
##   hand0:grab_strength                — 0 = open, 1 = full grab
##   hand0:pinch_strength               — 0 = open, 1 = pinching
##   hand0:confidence                   — tracking confidence 0–1
##   hand0:is_left                      — 1 = left hand, 0 = right
##
## Requires a sensor with hand tracking capability (e.g. Ultraleap).
## Sensors without hand tracking support output nothing.
##
## Requires the gn_ext_depth_sensor GDExtension (GNDepthSensor class).

var _sensor: RefCounted = null
var _last_serial: String = ""
var _last_backend: String = ""

# Capability flag for hand tracking (must match C++ enum)
const CAP_HAND_TRACK := 128


func _init() -> void:
	node_type = "depthhand"
	time_dependent = true
	node_description = "Hand and finger tracking from depth sensor."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "linux"])

func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Hand tracking channels")

func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("device",
		GNDepthSensorHelper.get_device_menu(), 0, "Device",
		"Connected sensor (First Available = auto-detect)"))
	add_parameter(GNParameter.create_float("min_confidence", 0.0, 0.0, 1.0, 0.01, "Min Confidence",
		"Minimum hand confidence to include (0 = all)"))
	add_parameter(GNParameter.create_string("finger_filter", "*", "Finger Filter",
		"Wildcard pattern for finger/bone names (* = all)"))
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
		GNLogger.warn("DepthHandCHOP", "'%s': gn_ext_depth_sensor not loaded" % id)
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
			GNLogger.warn("DepthHandCHOP", "'%s': no sensor backends compiled" % id)
			return null
		backend = backends[0]

	if serial != _last_serial or backend != _last_backend:
		_sensor.close_device()
		if not _sensor.open_device(serial, backend):
			GNLogger.warn("DepthHandCHOP", "'%s': failed to open %s device" % [id, backend])
			return null
		_last_serial = serial
		_last_backend = backend

	if not _sensor.is_device_open():
		return null

	# Check hand tracking capability
	if not _sensor.has_capability(CAP_HAND_TRACK):
		GNLogger.warn("DepthHandCHOP", "'%s': sensor does not support hand tracking" % id)
		return null

	# Capture
	var timeout: int = get_param_value("timeout_ms")
	if not _sensor.capture(timeout):
		return _cached_channel_data

	# Get hand data
	var hands: Array = _sensor.get_hand_data()
	if hands.is_empty():
		return _cached_channel_data

	var min_conf: float = get_param_value("min_confidence")
	var finger_filter: String = get_param_value("finger_filter")
	var out := _prepare_output(60.0)

	for h_idx in range(hands.size()):
		var hand: Dictionary = hands[h_idx]
		var conf: float = hand.get("confidence", 0.0)
		if conf < min_conf:
			continue

		var hand_prefix := "hand%d" % h_idx

		# Scalar channels
		out.set_single_value("%s:is_left" % hand_prefix, 1.0 if hand.get("is_left", false) else 0.0)
		out.set_single_value("%s:confidence" % hand_prefix, conf)
		out.set_single_value("%s:grab_strength" % hand_prefix, hand.get("grab_strength", 0.0))
		out.set_single_value("%s:pinch_strength" % hand_prefix, hand.get("pinch_strength", 0.0))

		# Palm
		_write_joint(out, "%s:palm" % hand_prefix, hand.get("palm", {}))

		# Wrist
		_write_joint(out, "%s:wrist" % hand_prefix, hand.get("wrist", {}))

		# Fingers
		var fingers: Array = hand.get("fingers", [])
		for finger_dict: Dictionary in fingers:
			var finger_name: String = finger_dict.get("name", "unknown")
			var bones: Array = finger_dict.get("bones", [])

			for bone_dict: Dictionary in bones:
				var bone_name: String = bone_dict.get("name", "unknown")
				if not _matches_filter(bone_name, finger_filter):
					continue

				var prefix := "%s:%s" % [hand_prefix, bone_name]
				_write_joint(out, prefix, bone_dict)

	return out


# ── Helpers ───────────────────────────────────────────────────────────────────

func _write_joint(out: GNData, prefix: String, joint: Dictionary) -> void:
	# Position (meters)
	out.set_single_value("%s:tx" % prefix, joint.get("x", 0.0))
	out.set_single_value("%s:ty" % prefix, joint.get("y", 0.0))
	out.set_single_value("%s:tz" % prefix, joint.get("z", 0.0))

	# Rotation (quaternion → euler degrees)
	var qx: float = joint.get("qx", 0.0)
	var qy: float = joint.get("qy", 0.0)
	var qz: float = joint.get("qz", 0.0)
	var qw: float = joint.get("qw", 1.0)
	var quat := Quaternion(qx, qy, qz, qw)
	var euler := quat.get_euler()
	out.set_single_value("%s:rx" % prefix, rad_to_deg(euler.x))
	out.set_single_value("%s:ry" % prefix, rad_to_deg(euler.y))
	out.set_single_value("%s:rz" % prefix, rad_to_deg(euler.z))

func _ensure_sensor() -> void:
	if _sensor != null:
		return
	_sensor = ClassDB.instantiate(&"GNDepthSensor")
	if _sensor == null:
		GNLogger.error("DepthHandCHOP", "'%s': failed to instantiate GNDepthSensor" % id)

func _matches_filter(name: String, pattern: String) -> bool:
	if pattern == "*" or pattern.is_empty():
		return true
	return name.matchn(pattern)
