class_name DepthSensorIMG
extends GNImgBase
## Multi-output depth sensor node — single capture per frame, multiple output
## types with demand-gated extraction (§25.24).
##
## Port 0 — IMG:  Depth, color, IR, or player index image (selectable)
## Port 1 — CHOP: Skeleton joint channels (body tracking)
## Port 2 — CHOP: Hand/finger tracking channels
## Port 3 — SOP:  Dense 3D point cloud mesh
##
## Each output only processes if that port is connected (is_output_demanded).
## The sensor capture is the shared core — runs once regardless of which
## outputs are wired.
##
## Supports multiple simultaneous sensors — each DepthSensorIMG node can
## target a different device by serial.  The device dropdown auto-refreshes
## when opened.
##
## Requires at least one gn_ext_depth_sensor backend DLL (GNDepthAzureKinect,
## GNDepthRealSense, or GNDepthUltraleap).

var _sensor: RefCounted = null
var _last_serial: String = ""
var _last_backend: String = ""

# Secondary output caches (port 0 uses _cached_image_data from GNImgBase)
var _cached_skeleton: GNChannelData = null
var _cached_hands: GNChannelData = null
var _cached_geo: GNGeoData = null

# Stream mode enum indices (for port 0 image selection)
const STREAM_DEPTH := 0
const STREAM_COLOR := 1
const STREAM_IR := 2
const STREAM_PLAYER_INDEX := 3

# Capability flags (must match C++ DepthSensorCapability enum)
const CAP_DEPTH := 1
const CAP_COLOR := 2
const CAP_IR := 4
const CAP_SKELETON := 8
const CAP_POINT_CLOUD := 16
const CAP_PLAYER_INDEX := 32
const CAP_HAND_TRACK := 128


func _init() -> void:
	node_type = "depthsensor"
	time_dependent = true
	node_description = "Multi-output depth sensor: image + skeleton + hands + point cloud."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "linux"])


func _init_ports() -> void:
	add_output("image", GNFamily.Type.IMG, "Sensor image (depth/color/IR/player index)", "Image")
	add_output("skeleton", GNFamily.Type.CHOP, "Skeleton joint channels (per-body)", "Skeleton")
	add_output("hands", GNFamily.Type.CHOP, "Hand/finger tracking channels", "Hands")
	add_output("points", GNFamily.Type.SOP, "Dense 3D point cloud mesh", "Points")


func _init_parameters() -> void:
	var device_param := GNParameter.create_enum("device",
		GNDepthSensorHelper.get_device_menu(), 0, "Device",
		"Connected sensor (First Available = auto-detect)")
	device_param.dynamic_enum_callback = Callable(GNDepthSensorHelper, "get_device_menu")
	add_parameter(device_param)

	add_parameter(GNParameter.create_enum("stream",
		PackedStringArray(["Depth", "Color", "IR", "Player Index"]), 0, "Stream",
		"Which image stream to output on port 0"))
	add_parameter(GNParameter.create_int("max_depth_mm", 5000, 500, 20000, "Max Depth (mm)",
		"Maximum depth range for depth visualization normalization"))
	add_parameter(GNParameter.create_int("max_bodies", 6, 1, 6, "Max Bodies",
		"Maximum number of tracked bodies to output"))
	add_parameter(GNParameter.create_float("min_confidence", 0.0, 0.0, 1.0, 0.01, "Min Confidence",
		"Minimum joint/hand confidence to include (0 = all)"))
	add_parameter(GNParameter.create_string("joint_filter", "*", "Joint Filter",
		"Wildcard pattern for skeleton joint names (* = all)"))
	add_parameter(GNParameter.create_string("finger_filter", "*", "Finger Filter",
		"Wildcard pattern for finger/bone names (* = all)"))
	add_parameter(GNParameter.create_bool("point_color", true, "Point Cloud Color",
		"Use color camera data for per-point color"))
	add_parameter(GNParameter.create_int("point_skip", 1, 1, 16, "Point Skip",
		"Sample every Nth point (1 = all, 4 = 1/4 density)"))
	add_parameter(GNParameter.create_float("point_max_depth", 5.0, 0.1, 20.0, 0.1, "Point Max Depth (m)",
		"Discard points beyond this distance in meters"))
	add_parameter(GNParameter.create_int("timeout_ms", 33, 0, 1000, "Timeout",
		"Frame capture timeout in milliseconds"))
	add_parameter(GNParameter.create_bool("active", true, "Enable or disable the operator",
		"Enable / disable sensor capture"))


# ── Cook ──────────────────────────────────────────────────────────────────────

func _cook(_inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()

	if not GNDepthSensorHelper.is_available():
		GNLogger.warn("DepthSensorIMG", "'%s': gn_ext_depth_sensor not loaded" % id)
		return out

	if not get_param_value("active"):
		return out

	# ── Device selection ──────────────────────────────────────────────
	var dev := GNDepthSensorHelper.get_device_at(get_param_value("device"))
	var serial: String = dev.get("serial", "")
	var backend: String = dev.get("backend", "")

	if backend.is_empty():
		var backends := GNDepthSensorHelper.get_backends()
		if backends.is_empty():
			GNLogger.warn("DepthSensorIMG", "'%s': no sensor backends loaded" % id)
			return out
		backend = backends[0]

	_ensure_sensor(backend)
	if _sensor == null:
		return out

	if serial != _last_serial or backend != _last_backend:
		_sensor.close_device()
		if not _sensor.open_device(serial, backend):
			GNLogger.warn("DepthSensorIMG", "'%s': failed to open %s device '%s'" % [id, backend, serial])
			return out
		_last_serial = serial
		_last_backend = backend

	if not _sensor.is_device_open():
		return out

	# ── Shared core: capture one frame (§25.24) ──────────────────────
	var timeout: int = get_param_value("timeout_ms")
	if not _sensor.capture(timeout):
		return out

	# ── Port 0: Image output (only if demanded) ─────────────────────
	if is_output_demanded(0):
		_cook_image(out)

	# ── Port 1: Skeleton CHOP (only if demanded) ────────────────────
	if is_output_demanded(1):
		_cook_skeleton()

	# ── Port 2: Hand CHOP (only if demanded) ────────────────────────
	if is_output_demanded(2):
		_cook_hands()

	# ── Port 3: Point cloud SOP (only if demanded) ──────────────────
	if is_output_demanded(3):
		_cook_point_cloud()

	return out


func get_output_data(port_index: int) -> GNData:
	match port_index:
		1: return _cached_skeleton
		2: return _cached_hands
		3: return _cached_geo
		_: return cached_output


# ── Port 0: Image ────────────────────────────────────────────────────────────

func _cook_image(out: GNImageData) -> void:
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
			w = _sensor.get_depth_width()
			h = _sensor.get_depth_height()

	if rgba.is_empty() or w <= 0 or h <= 0:
		return

	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba)
	out.set_image(img)


# ── Port 1: Skeleton ────────────────────────────────────────────────────────

func _cook_skeleton() -> void:
	if _cached_skeleton == null:
		_cached_skeleton = GNChannelData.new()
	_cached_skeleton.channels.clear()

	if not _sensor.has_capability(CAP_SKELETON):
		return

	var bodies: Array = _sensor.get_skeleton_data()
	if bodies.is_empty():
		return

	var max_bodies: int = get_param_value("max_bodies")
	var min_conf: float = get_param_value("min_confidence")
	var joint_filter: String = get_param_value("joint_filter")

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
			_cached_skeleton.set_single_value("%s:tx" % prefix, joint_dict.get("x", 0.0))
			_cached_skeleton.set_single_value("%s:ty" % prefix, joint_dict.get("y", 0.0))
			_cached_skeleton.set_single_value("%s:tz" % prefix, joint_dict.get("z", 0.0))

			var quat := Quaternion(
				joint_dict.get("qx", 0.0), joint_dict.get("qy", 0.0),
				joint_dict.get("qz", 0.0), joint_dict.get("qw", 1.0))
			var euler := quat.get_euler()
			_cached_skeleton.set_single_value("%s:rx" % prefix, rad_to_deg(euler.x))
			_cached_skeleton.set_single_value("%s:ry" % prefix, rad_to_deg(euler.y))
			_cached_skeleton.set_single_value("%s:rz" % prefix, rad_to_deg(euler.z))
			_cached_skeleton.set_single_value("%s:confidence" % prefix, conf)


# ── Port 2: Hands ───────────────────────────────────────────────────────────

func _cook_hands() -> void:
	if _cached_hands == null:
		_cached_hands = GNChannelData.new()
	_cached_hands.channels.clear()

	if not _sensor.has_capability(CAP_HAND_TRACK):
		return

	var hands: Array = _sensor.get_hand_data()
	if hands.is_empty():
		return

	var min_conf: float = get_param_value("min_confidence")
	var finger_filter: String = get_param_value("finger_filter")

	for h_idx in range(hands.size()):
		var hand: Dictionary = hands[h_idx]
		var conf: float = hand.get("confidence", 0.0)
		if conf < min_conf:
			continue

		var hp := "hand%d" % h_idx
		_cached_hands.set_single_value("%s:is_left" % hp, 1.0 if hand.get("is_left", false) else 0.0)
		_cached_hands.set_single_value("%s:confidence" % hp, conf)
		_cached_hands.set_single_value("%s:grab_strength" % hp, hand.get("grab_strength", 0.0))
		_cached_hands.set_single_value("%s:pinch_strength" % hp, hand.get("pinch_strength", 0.0))

		_write_joint(_cached_hands, "%s:palm" % hp, hand.get("palm", {}))
		_write_joint(_cached_hands, "%s:wrist" % hp, hand.get("wrist", {}))

		var fingers: Array = hand.get("fingers", [])
		for finger_dict: Dictionary in fingers:
			var bones: Array = finger_dict.get("bones", [])
			for bone_dict: Dictionary in bones:
				var bone_name: String = bone_dict.get("name", "unknown")
				if not _matches_filter(bone_name, finger_filter):
					continue
				_write_joint(_cached_hands, "%s:%s" % [hp, bone_name], bone_dict)


# ── Port 3: Point Cloud ─────────────────────────────────────────────────────

func _cook_point_cloud() -> void:
	if not _sensor.has_capability(CAP_POINT_CLOUD):
		return

	var positions: PackedFloat32Array = _sensor.get_point_cloud_positions()
	if positions.is_empty():
		return

	var use_color: bool = get_param_value("point_color") and _sensor.has_capability(CAP_COLOR)
	var colors: PackedByteArray
	if use_color:
		colors = _sensor.get_point_cloud_colors()

	var skip: int = maxi(1, get_param_value("point_skip"))
	var max_depth: float = get_param_value("point_max_depth")

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)

	var point_count: int = positions.size() / 3
	var has_colors: bool = use_color and colors.size() >= point_count * 4

	for i in range(0, point_count, skip):
		var x: float = positions[i * 3]
		var y: float = positions[i * 3 + 1]
		var z: float = positions[i * 3 + 2]

		if absf(z) < 0.001 or absf(z) > max_depth:
			continue

		if has_colors:
			var r: float = colors[i * 4] / 255.0
			var g: float = colors[i * 4 + 1] / 255.0
			var b: float = colors[i * 4 + 2] / 255.0
			st.set_color(Color(r, g, b, 1.0))

		st.set_normal(Vector3(0, 0, -1))
		st.add_vertex(Vector3(x, -y, -z))

	var arr_mesh := ArrayMesh.new()
	st.commit(arr_mesh)
	_cached_geo.set_mesh(arr_mesh)


# ── Shared Helpers ───────────────────────────────────────────────────────────

func _write_joint(out: GNChannelData, prefix: String, joint: Dictionary) -> void:
	out.set_single_value("%s:tx" % prefix, joint.get("x", 0.0))
	out.set_single_value("%s:ty" % prefix, joint.get("y", 0.0))
	out.set_single_value("%s:tz" % prefix, joint.get("z", 0.0))
	var quat := Quaternion(
		joint.get("qx", 0.0), joint.get("qy", 0.0),
		joint.get("qz", 0.0), joint.get("qw", 1.0))
	var euler := quat.get_euler()
	out.set_single_value("%s:rx" % prefix, rad_to_deg(euler.x))
	out.set_single_value("%s:ry" % prefix, rad_to_deg(euler.y))
	out.set_single_value("%s:rz" % prefix, rad_to_deg(euler.z))


func _ensure_sensor(backend: String) -> void:
	# Each backend is a separate class — recreate if backend changed.
	if _sensor != null and backend == _last_backend:
		return
	if _sensor != null:
		_sensor.close_device()
		_sensor = null
	_sensor = GNDepthSensorHelper.create_sensor(backend)
	if _sensor == null:
		GNLogger.error("DepthSensorIMG", "'%s': failed to instantiate sensor for '%s'" % [id, backend])


func _matches_filter(name: String, pattern: String) -> bool:
	if pattern == "*" or pattern.is_empty():
		return true
	return name.matchn(pattern)
