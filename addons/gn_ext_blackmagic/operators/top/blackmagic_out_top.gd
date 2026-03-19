class_name BlackmagicOutTOP
extends GNTopBase
## Output video to SDI/HDMI via a Blackmagic DeckLink device.
##
## Takes a TOP input texture, converts to Image, and sends to the
## GNBlackmagic GDExtension for DeckLink scheduled output.

var _bm: Node = null
var _active_device: int = -1


func _init() -> void:
	node_type = "blackmagicout"
	time_dependent = true
	node_description = "Output video to SDI/HDMI via a Blackmagic DeckLink device."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Video texture to output")
	add_output("out", GNFamily.Type.TOP, "Pass-through of input")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("device", 0, 0, 15,
		"Device Index", "DeckLink output device index"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(1920, 1080),
		"Resolution", "Output resolution"))
	add_parameter(GNParameter.create_enum("fps",
		PackedStringArray(["23.98", "24", "25", "29.97", "30", "50", "59.94", "60"]), 4,
		"Frame Rate", "Output frame rate"))
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "Enable output to device"))


func _cook(inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	var active: bool = get_param_value("active")

	# Pass through input
	var in_tex: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if in_tex != null:
		_cached_tex_data = in_tex

	if not active or in_tex == null:
		_close_output()
		return _cached_tex_data

	# Ensure native library
	if _bm == null:
		if not ClassDB.class_exists(&"GNBlackmagic"):
			GNLogger.warn("BlackmagicOutTOP", "'%s' — GNBlackmagic native library not available" % id)
			return _cached_tex_data
		_bm = ClassDB.instantiate(&"GNBlackmagic")
		add_child(_bm)

	# Open output if needed
	var dev: int = get_param_value("device")
	if dev != _active_device:
		_close_output()
		var fps_val: float = _fps_from_index(get_param_value("fps"))
		if _bm.call("open_output", dev, res.x, res.y, fps_val):
			_active_device = dev
			GNLogger.info("BlackmagicOutTOP", "'%s' — outputting to device %d" % [id, dev])
		else:
			GNLogger.warn("BlackmagicOutTOP", "'%s' — failed to open output device %d" % [id, dev])
			return _cached_tex_data

	# Send frame
	if in_tex.texture != null:
		var img: Image = in_tex.texture.get_image()
		if img != null:
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			if img.get_size() != Vector2i(res.x, res.y):
				img.resize(res.x, res.y)
			_bm.call("send_frame", img)

	return _cached_tex_data


func _close_output() -> void:
	if _bm != null and _active_device >= 0:
		_bm.call("close_output")
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
		_close_output()
		if _bm != null:
			_bm.queue_free()
			_bm = null
