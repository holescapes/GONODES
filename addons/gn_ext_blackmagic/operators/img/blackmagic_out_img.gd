class_name BlackmagicOutIMG
extends GNImgBase
## DeckLink video output — sends an IMG input to a DeckLink device.
##
## Takes RGBA image data on port 0, converts to UYVY in C++, and
## schedules it for playback on the selected DeckLink output.
##
## No GPU roundtrip — operates entirely on CPU-side Image data.
##
## Requires the gn_ext_blackmagic GDExtension (GNBlackmagic class).

var _bm: Node = null
var _last_device_idx: int = -1

# Resolution presets (must match enum order)
const RES_WIDTHS := [1280, 1920, 3840]
const RES_HEIGHTS := [720, 1080, 2160]

# FPS presets (must match enum order)
const FPS_VALUES := [23.976, 24.0, 25.0, 29.97, 30.0, 50.0, 59.94, 60.0]


func _init() -> void:
	node_type = "blackmagicout"
	time_dependent = true
	node_description = "DeckLink video output: sends IMG to a DeckLink device."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows"])


func _init_ports() -> void:
	add_input("image", GNFamily.Type.IMG, false, "Image to output (RGBA)", "Image")
	add_output("thru", GNFamily.Type.IMG, "Pass-through of input image", "Thru")


func _init_parameters() -> void:
	var device_param := GNParameter.create_enum("device",
		GNBlackmagicHelper.get_output_device_menu(), 0, "Device",
		"DeckLink output device")
	device_param.dynamic_enum_callback = Callable(GNBlackmagicHelper, "get_output_device_menu")
	add_parameter(device_param)

	add_parameter(GNParameter.create_enum("resolution",
		PackedStringArray(["720p", "1080p", "2160p (4K)"]), 1, "Resolution",
		"Output resolution"))
	add_parameter(GNParameter.create_enum("fps",
		PackedStringArray(["23.976", "24", "25", "29.97", "30", "50", "59.94", "60"]),
		4, "FPS", "Frame rate"))
	add_parameter(GNParameter.create_bool("active", true, "Active",
		"Enable/disable output"))


# ── Cook ──────────────────────────────────────────────────────────────────────

func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()
	var in_img: GNImageData = _get_input_img(inputs, 0)

	# Pass-through regardless of output state
	if in_img != null and in_img.image != null:
		out.set_image(in_img.image)

	if not GNBlackmagicHelper.is_available():
		GNLogger.warn("BlackmagicOutIMG", "'%s': gn_ext_blackmagic not loaded" % id)
		return out

	var active: bool = get_param_value("active")
	if not active:
		_close_output()
		return out

	if in_img == null or in_img.image == null:
		return out

	_ensure_native()
	if _bm == null:
		return out

	# ── Device selection ──────────────────────────────────────────────
	var device_idx: int = get_param_value("device")
	if device_idx == 0:
		_close_output()
		return out

	var res_idx: int = get_param_value("resolution")
	var fps_idx: int = get_param_value("fps")
	var w: int = RES_WIDTHS[res_idx]
	var h: int = RES_HEIGHTS[res_idx]
	var fps: float = FPS_VALUES[fps_idx]

	# Re-open if device/resolution/fps changed
	if device_idx != _last_device_idx or not _bm.call("is_output_active"):
		_close_output()
		var real_idx: int = device_idx - 1
		if not _bm.call("open_output", real_idx, w, h, fps):
			GNLogger.warn("BlackmagicOutIMG", "'%s': open_output failed for device %d" % [id, real_idx])
			return out
		_last_device_idx = device_idx

	# ── Send frame (RGBA → UYVY conversion happens in C++) ──────────
	_bm.call("send_frame", in_img.image)

	return out


# ── Helpers ──────────────────────────────────────────────────────────────────

func _ensure_native() -> void:
	if _bm != null:
		return
	_bm = GNBlackmagicHelper.get_native()


func _close_output() -> void:
	if _bm != null and _bm.call("is_output_active"):
		_bm.call("close_output")
	_last_device_idx = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_close_output()
