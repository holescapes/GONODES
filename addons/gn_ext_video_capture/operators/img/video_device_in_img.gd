class_name VideoDeviceInIMG
extends GNImgBase
## Capture live video from a webcam or capture device as a CPU-side Image.
## Cross-platform: Media Foundation (Windows), AVFoundation (macOS), V4L2 (Linux).
## Chain → ImgToTOP if you need a GPU texture downstream.

var _capture: RefCounted = null
var _device_open := false
var _prev_device := -1
var _prev_width := 0
var _prev_height := 0
var _prev_fps := 0


func _init() -> void:
	node_type = "videodeviceinimg"
	time_dependent = true
	node_description = "Live video capture from webcam or external capture device (CPU Image)."
	if ClassDB.class_exists("GNVideoCapture"):
		_capture = ClassDB.instantiate("GNVideoCapture")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.IMG, "Captured video frame (CPU Image)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("device_index", 0, 0, 15, "Device",
		"Capture device index (0 = first webcam)."))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(1920, 1080),
		"Resolution", "Requested capture resolution."))
	add_parameter(GNParameter.create_int("fps", 30, 1, 120, "FPS",
		"Requested capture framerate."))
	add_parameter(GNParameter.create_bool("active", true, "Active",
		"Enable/disable capture."))


func _cook(_inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()

	if _capture == null:
		node_warning = "Video capture requires the native gn_ext_video_capture library."
		return out

	var active: bool = get_param_value("active")
	if not active:
		if _device_open:
			_capture.close_device()
			_device_open = false
		return out

	var device_index: int = get_param_value("device_index")
	var resolution: Vector2i = get_param_value("resolution")
	var fps: int = get_param_value("fps")

	# Re-open device if settings changed
	if not _device_open or device_index != _prev_device \
			or resolution.x != _prev_width or resolution.y != _prev_height \
			or fps != _prev_fps:
		_capture.close_device()
		if not _capture.open_device(device_index, resolution.x, resolution.y, fps):
			node_warning = "Failed to open capture device %d." % device_index
			_device_open = false
			return out
		_device_open = true
		_prev_device = device_index
		_prev_width = resolution.x
		_prev_height = resolution.y
		_prev_fps = fps

	var rgba: PackedByteArray = _capture.capture_frame()
	if rgba.is_empty():
		return out

	var w: int = _capture.get_width()
	var h: int = _capture.get_height()
	if w <= 0 or h <= 0:
		return out

	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba)
	out.set_image(img)
	return out


func _on_node_removed() -> void:
	if _capture != null and _device_open:
		_capture.close_device()
		_device_open = false
