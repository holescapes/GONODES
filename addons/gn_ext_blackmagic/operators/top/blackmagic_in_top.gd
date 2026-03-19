class_name BlackmagicInTOP
extends GNTopBase
## Capture SDI/HDMI video from a Blackmagic DeckLink device.
##
## Reads frames from the GNBlackmagic GDExtension and presents them
## as a TOP texture.  Requires DeckLink hardware + drivers.

var _bm: Node = null  # GNBlackmagic instance (ClassDB)
var _image_texture: ImageTexture = null
var _active_device: int = -1


func _init() -> void:
	node_type = "blackmagicin"
	time_dependent = true
	node_description = "Capture SDI/HDMI video input from a Blackmagic DeckLink device."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Captured video frame")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("device", 0, 0, 15,
		"Device Index", "DeckLink device index (0 = first)"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(1920, 1080),
		"Resolution", "Capture resolution"))
	add_parameter(GNParameter.create_enum("fps",
		PackedStringArray(["23.98", "24", "25", "29.97", "30", "50", "59.94", "60"]), 4,
		"Frame Rate", "Capture frame rate"))
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "Enable capture from device"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	_ensure_viewport(res)
	if _viewport.size != res:
		_viewport.size = res

	var active: bool = get_param_value("active")

	if not active:
		_close_capture()
		_cached_tex_data.resolution = res
		return _cached_tex_data

	# Ensure GNBlackmagic native class exists
	if _bm == null:
		if not ClassDB.class_exists(&"GNBlackmagic"):
			GNLogger.warn("BlackmagicInTOP", "'%s' — GNBlackmagic native library not available" % id)
			_cached_tex_data.resolution = res
			return _cached_tex_data
		_bm = ClassDB.instantiate(&"GNBlackmagic")
		add_child(_bm)

	# Open input if not active or device changed
	var dev: int = get_param_value("device")
	if dev != _active_device:
		_close_capture()
		var fps_val: float = _fps_from_index(get_param_value("fps"))
		if _bm.call("open_input", dev, res.x, res.y, fps_val):
			_active_device = dev
			GNLogger.info("BlackmagicInTOP", "'%s' — capturing from device %d" % [id, dev])
		else:
			GNLogger.warn("BlackmagicInTOP", "'%s' — failed to open device %d" % [id, dev])

	# Read frame
	if _bm.call("has_new_frame"):
		var img: Image = _bm.call("get_frame")
		if img != null:
			if _image_texture == null:
				_image_texture = ImageTexture.create_from_image(img)
			else:
				_image_texture.update(img)
			_cached_tex_data.texture = _image_texture

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _close_capture() -> void:
	if _bm != null and _active_device >= 0:
		_bm.call("close_input")
	_active_device = -1


func _fps_from_index(idx: int) -> float:
	match idx:
		0: return 23.98
		1: return 24.0
		2: return 25.0
		3: return 29.97
		4: return 30.0
		5: return 50.0
		6: return 59.94
		7: return 60.0
		_: return 30.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_close_capture()
		if _bm != null:
			_bm.queue_free()
			_bm = null
