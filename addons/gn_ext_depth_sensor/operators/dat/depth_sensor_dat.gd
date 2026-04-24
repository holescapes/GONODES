class_name DepthSensorDAT
extends GNDatBase
## Lists all connected depth sensors with their capabilities, serial numbers,
## and backend information.  Useful for setup, debugging, and device selection.
##
## Output columns: name, serial, backend, depth, color, ir, skeleton,
## point_cloud, player_index, floor_plane, hand_track.
##
## Requires at least one gn_ext_depth_sensor backend DLL (GNDepthAzureKinect,
## GNDepthRealSense, or GNDepthUltraleap).

# Capability flag constants (must match C++ enum)
const CAP_DEPTH := 1
const CAP_COLOR := 2
const CAP_IR := 4
const CAP_SKELETON := 8
const CAP_POINT_CLOUD := 16
const CAP_PLAYER_INDEX := 32
const CAP_FLOOR_PLANE := 64
const CAP_HAND_TRACK := 128


func _init() -> void:
	node_type = "depthsensordat"
	node_description = "Lists connected depth sensors and their capabilities."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "linux"])

func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Sensor info table")

func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", true, "Enable or disable the operator",
		"Enable / disable device enumeration"))
	add_parameter(GNParameter.create_pulse("rescan", "Rescan Devices",
		"Re-enumerate connected sensors and refresh cached device list"))


func _pre_cook(_delta: float) -> void:
	if get_param_value("rescan"):
		set_param_value("rescan", false)
		GNDepthSensorHelper.rescan()
		mark_dirty()


func _cook(_inputs: Array[GNData]) -> GNData:
	if not GNDepthSensorHelper.is_available():
		GNLogger.warn("DepthSensorDAT", "'%s': gn_ext_depth_sensor not loaded" % id)
		return null

	if not get_param_value("active"):
		return cached_output

	# Enumerate all devices across all loaded backends
	var all_devices: Array = []
	for backend_name: String in GNDepthSensorHelper.get_backends():
		var sensor := GNDepthSensorHelper.create_sensor(backend_name)
		if sensor == null:
			continue
		var devs: Array = sensor.enumerate_devices()
		for dev: Dictionary in devs:
			all_devices.append(dev)

	# Build header
	var columns: PackedStringArray = [
		"name", "serial", "backend",
		"depth", "color", "ir", "skeleton",
		"point_cloud", "player_index", "floor_plane", "hand_track"
	]

	var rows: Array[PackedStringArray] = []
	rows.append(columns)  # Header row

	for dev: Dictionary in all_devices:
		var backend_name: String = dev.get("backend", "")

		# Open device briefly to read capabilities
		var caps: int = 0
		var sensor := GNDepthSensorHelper.create_sensor(backend_name)
		if sensor != null and sensor.open_device(dev.get("serial", ""), backend_name):
			caps = sensor.get_capabilities()
			sensor.close_device()

		var row: PackedStringArray = [
			dev.get("name", "unknown"),
			dev.get("serial", ""),
			backend_name,
			"yes" if (caps & CAP_DEPTH) else "no",
			"yes" if (caps & CAP_COLOR) else "no",
			"yes" if (caps & CAP_IR) else "no",
			"yes" if (caps & CAP_SKELETON) else "no",
			"yes" if (caps & CAP_POINT_CLOUD) else "no",
			"yes" if (caps & CAP_PLAYER_INDEX) else "no",
			"yes" if (caps & CAP_FLOOR_PLANE) else "no",
			"yes" if (caps & CAP_HAND_TRACK) else "no",
		]
		rows.append(row)

	var out := _prepare_table()
	out.has_header = true
	out.is_table = true
	for r: PackedStringArray in rows:
		out.table.append(r)
	return out
