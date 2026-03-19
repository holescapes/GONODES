class_name NDIInTOP
extends GNTopBase
## Receives an NDI video stream over the network and outputs it as a texture.
##
## Requires the gn_ext_ndi GDExtension (GNNDIReceiver class).
## See addons/gn_ext_ndi/README.md for SDK setup instructions.

var _receiver: RefCounted = null
var _last_source: String = ""


func _init() -> void:
	node_type = "ndiin"
	time_dependent = true
	node_description = "Receive NDI video from the network. Requires gn_ext_ndi."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])

func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Received video frame")

func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("source", "", "Source",
		"NDI source name (e.g. 'OBS (DESKTOP-ABC)')"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(1920, 1080), "",
		"Output resolution (auto-set from stream when 0×0)"))
	add_parameter(GNParameter.create_enum("bandwidth",
		PackedStringArray(["Highest", "Audio Only", "Lowest"]), 0, "Bandwidth",
		"NDI receive quality"))
	add_parameter(GNParameter.create_int("timeout_ms", 16, 0, 1000, "Timeout",
		"Frame capture timeout in milliseconds"))
	add_parameter(GNParameter.create_bool("active", true, "",
		"Enable / disable receiving"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if not _is_ndi_available():
		GNLogger.warn("NDIInTOP", "'%s': gn_ext_ndi GDExtension not loaded" % id)
		return null

	if not get_param_value("active"):
		return _cached_tex_data

	_ensure_receiver()
	if _receiver == null:
		return null

	var source_name: String = get_param_value("source")
	if source_name != _last_source:
		if source_name.is_empty():
			_receiver.release()
		else:
			_receiver.create_receiver(source_name, get_param_value("bandwidth"))
		_last_source = source_name

	if not _receiver.is_receiver_connected():
		return null

	var timeout: int = get_param_value("timeout_ms")
	var rgba: PackedByteArray = _receiver.receive_video(timeout)
	if rgba.is_empty():
		return _cached_tex_data

	var w: int = _receiver.get_video_width()
	var h: int = _receiver.get_video_height()
	if w <= 0 or h <= 0:
		return _cached_tex_data

	# Auto-set resolution from stream
	var res: Vector2i = get_param_value("resolution")
	if res != Vector2i(w, h):
		set_param_value("resolution", Vector2i(w, h))

	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba)
	var tex := ImageTexture.create_from_image(img)

	if _cached_tex_data == null:
		_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = tex
	_cached_tex_data.resolution = Vector2i(w, h)
	_cached_tex_data.format = Image.FORMAT_RGBA8
	return _cached_tex_data


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _is_ndi_available() -> bool:
	return ClassDB.class_exists(&"GNNDIReceiver")

func _ensure_receiver() -> void:
	if _receiver != null:
		return
	_receiver = ClassDB.instantiate(&"GNNDIReceiver")
	if _receiver == null:
		GNLogger.error("NDIInTOP", "'%s': failed to instantiate GNNDIReceiver" % id)
