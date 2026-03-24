class_name WebcamIMG
extends GNImgBase
## Live camera feed as a CPU-side Image via Godot's CameraServer.
##
## Reads each frame from the selected camera device and outputs it as
## GNImageData.  Chain → ImgToTOP if you need a GPU texture downstream.
##
## NOTE: On first use, the OS may prompt for camera permission.
## Not all platforms support CameraServer (works on Windows, macOS, Linux
## with appropriate drivers; limited on web/mobile).

## CameraTexture used to read back the camera feed as a CPU Image.
var _camera_texture: CameraTexture = null

## Currently active feed ID (CameraServer-assigned, not our "device" param).
var _active_feed_id: int = -1

## CameraFeed reference for the active camera.
var _camera_feed: CameraFeed = null


func _init() -> void:
	node_type = "webcam"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.IMG, "Camera frame (CPU Image)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("device", 0, 0, 8,
		"Device", "Camera device index (0 = first camera)"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(640, 480),
		"Resolution", "Desired output resolution (image is resized to this)"))
	add_parameter(GNParameter.create_bool("active", true,
		"Active", "Enable/disable the camera feed"))
	add_parameter(GNParameter.create_bool("mirror_h", false,
		"Mirror H", "Flip the image horizontally"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()

	var device_idx: int = get_param_value("device")
	var res: Vector2i = get_param_value("resolution")
	var active: bool = get_param_value("active")
	var mirror: bool = get_param_value("mirror_h")

	if not active:
		if _camera_feed != null and _camera_feed.is_active():
			_camera_feed.set_active(false)
		return out

	# Resolve the camera feed for the requested device index.
	_resolve_feed(device_idx)

	if _camera_feed == null:
		GNLogger.debug("WebcamIMG",
			"'%s': No camera available at device index %d" % [id, device_idx])
		return out

	# Ensure feed is active.
	if not _camera_feed.is_active():
		_camera_feed.set_active(true)

	# Ensure we have a CameraTexture pointing at this feed.
	if _camera_texture == null or _camera_texture.camera_feed_id != _camera_feed.get_id():
		_camera_texture = CameraTexture.new()
		_camera_texture.camera_feed_id = _camera_feed.get_id()
		_camera_texture.which_feed = CameraServer.FEED_RGBA_IMAGE

	# Read the current frame as a CPU image.
	var image: Image = _camera_texture.get_image()
	if image == null:
		GNLogger.debug("WebcamIMG",
			"'%s': get_image() returned null (feed may not be ready yet)" % id)
		return out

	# Resize if needed.
	if image.get_size() != res:
		image.resize(res.x, res.y, Image.INTERPOLATE_BILINEAR)

	# Horizontal mirror.
	if mirror:
		image.flip_x()

	out.set_image(image)
	return out


# ─── Feed Resolution ───────────────────────────────────────────────────────────

func _resolve_feed(device_idx: int) -> void:
	var feed_count: int = CameraServer.get_feed_count()
	if feed_count == 0:
		_camera_feed = null
		_active_feed_id = -1
		return

	var idx: int = clampi(device_idx, 0, feed_count - 1)
	var feed: CameraFeed = CameraServer.get_feed(idx)

	if feed == null:
		_camera_feed = null
		_active_feed_id = -1
		return

	# Switch feeds only when the device changes.
	if feed.get_id() != _active_feed_id:
		if _camera_feed != null and _camera_feed.is_active():
			_camera_feed.set_active(false)
		_camera_feed = feed
		_active_feed_id = feed.get_id()
		_camera_texture = null  # Force new CameraTexture for new feed.
