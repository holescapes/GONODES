class_name BlackmagicInIMG
extends GNImgBase
## Multi-output DeckLink capture node — video input plus status channels.
##
## Port 0 — IMG:  Captured video frame (RGBA)
## Port 1 — CHOP: Signal status channels (dropped frames, timecode, signal)
##
## Demand-gated per §25.24: port 1 status channels only cook if connected.
## The capture runs once per frame regardless of which outputs are wired.
##
## Requires the gn_ext_blackmagic GDExtension (GNBlackmagic class).

var _bm: Node = null
var _cached_status: GNChannelData = null
var _last_device_idx: int = -1

# Resolution presets (must match enum order)
const RES_720P := 0
const RES_1080P := 1
const RES_2160P := 2

const RES_WIDTHS := [1280, 1920, 3840]
const RES_HEIGHTS := [720, 1080, 2160]

# FPS presets (must match enum order)
const FPS_VALUES := [23.976, 24.0, 25.0, 29.97, 30.0, 50.0, 59.94, 60.0]


func _init() -> void:
	node_type = "blackmagicin"
	time_dependent = true
	node_description = "DeckLink video capture: RGBA image + signal status."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows"])


func _init_ports() -> void:
	add_output("image", GNFamily.Type.IMG, "Captured video frame (RGBA)", "Image")
	add_output("status", GNFamily.Type.CHOP, "Signal status (dropped, timecode, active)", "Status")


func _init_parameters() -> void:
	var device_param := GNParameter.create_enum("device",
		GNBlackmagicHelper.get_input_device_menu(), 0, "Device",
		"DeckLink input device")
	device_param.dynamic_enum_callback = Callable(GNBlackmagicHelper, "get_input_device_menu")
	add_parameter(device_param)

	add_parameter(GNParameter.create_enum("resolution",
		PackedStringArray(["720p", "1080p", "2160p (4K)"]), 1, "Resolution",
		"Capture resolution"))
	add_parameter(GNParameter.create_enum("fps",
		PackedStringArray(["23.976", "24", "25", "29.97", "30", "50", "59.94", "60"]),
		4, "FPS", "Frame rate"))
	add_parameter(GNParameter.create_bool("active", true, "Active",
		"Enable/disable capture"))


# ── Cook ──────────────────────────────────────────────────────────────────────

func _cook(_inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()

	if not GNBlackmagicHelper.is_available():
		GNLogger.warn("BlackmagicInIMG", "'%s': gn_ext_blackmagic not loaded" % id)
		return out

	var active: bool = get_param_value("active")
	if not active:
		_close_capture()
		return out

	_ensure_native()
	if _bm == null:
		return out

	# ── Device selection ──────────────────────────────────────────────
	var device_idx: int = get_param_value("device")
	if device_idx == 0:
		# "No Device" selected
		_close_capture()
		return out

	var res_idx: int = get_param_value("resolution")
	var fps_idx: int = get_param_value("fps")
	var w: int = RES_WIDTHS[res_idx]
	var h: int = RES_HEIGHTS[res_idx]
	var fps: float = FPS_VALUES[fps_idx]

	# Re-open if device/resolution/fps changed
	if device_idx != _last_device_idx or not _bm.call("is_input_active"):
		_close_capture()
		var real_idx: int = device_idx - 1  # Menu index 0 = "No Device"
		if not _bm.call("open_input", real_idx, w, h, fps):
			GNLogger.warn("BlackmagicInIMG", "'%s': open_input failed for device %d" % [id, real_idx])
			return out
		_last_device_idx = device_idx

	# ── Shared core: check for new frame ─────────────────────────────
	if not _bm.call("has_new_frame"):
		return out

	# ── Port 0: Image output (only if demanded) ─────────────────────
	if is_output_demanded(0):
		var img: Image = _bm.call("get_frame")
		if img != null:
			out.set_image(img)

	# ── Port 1: Status CHOP (only if demanded) ──────────────────────
	if is_output_demanded(1):
		_cook_status()

	return out


func get_output_data(port_index: int) -> GNData:
	match port_index:
		1: return _cached_status
		_: return cached_output


# ── Port 1: Status CHOP ──────────────────────────────────────────────────────

func _cook_status() -> void:
	if _cached_status == null:
		_cached_status = GNChannelData.new()
	_cached_status.channels.clear()

	if _bm == null:
		return

	_cached_status.set_single_value("active", 1.0 if _bm.call("is_input_active") else 0.0)
	_cached_status.set_single_value("dropped", float(_bm.call("get_dropped_frames")))

	var tc: Dictionary = _bm.call("get_timecode")
	_cached_status.set_single_value("tc_hours", float(tc.get("hours", 0)))
	_cached_status.set_single_value("tc_minutes", float(tc.get("minutes", 0)))
	_cached_status.set_single_value("tc_seconds", float(tc.get("seconds", 0)))
	_cached_status.set_single_value("tc_frames", float(tc.get("frames", 0)))


# ── Helpers ──────────────────────────────────────────────────────────────────

func _ensure_native() -> void:
	if _bm != null:
		return
	_bm = GNBlackmagicHelper.get_native()


func _close_capture() -> void:
	if _bm != null and _bm.call("is_input_active"):
		_bm.call("close_input")
	_last_device_idx = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_close_capture()
