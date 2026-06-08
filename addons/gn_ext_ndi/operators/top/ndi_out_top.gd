class_name NDIOutTOP
extends GNTopBase
## Sends an input texture as an NDI video stream on the network.
##
## Requires the gn_ext_ndi GDExtension (GNNDISender class).
## See addons/gn_ext_ndi/README.md for SDK setup instructions.

var _sender: RefCounted = null
var _last_name: String = ""


func _init() -> void:
	node_type = "ndiout"
	time_dependent = true
	node_description = "Send a texture as NDI video to the network. Requires gn_ext_ndi."

func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])

func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, true, "Texture to send", "Video")
	add_output("thru", GNFamily.Type.TOP, "Pass-through of input", "Thru")

func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("name", "GoNodes", "Name",
		"NDI sender name visible on the network"))
	add_parameter(GNParameter.create_int("fps_n", 30, 1, 120, "FPS Num",
		"Frame-rate numerator"))
	add_parameter(GNParameter.create_int("fps_d", 1, 1, 1001, "FPS Den",
		"Frame-rate denominator"))
	add_parameter(GNParameter.create_bool("active", true, "Enable or disable the operator",
		"Enable / disable sending"))


func _cook(inputs: Array[GNData]) -> GNData:
	if not _is_ndi_available():
		GNLogger.warn("NDIOutTOP", "'%s': gn_ext_ndi GDExtension not loaded" % id)
		return null

	var in_tex: GNTextureData = _get_input_top(inputs, 0)
	if in_tex == null or in_tex.texture == null:
		return null

	if not get_param_value("active"):
		return in_tex

	_ensure_sender()
	if _sender == null:
		return in_tex

	var sender_name: String = get_param_value("name")
	if sender_name != _last_name:
		_sender.create_sender(sender_name)
		_last_name = sender_name

	if not _sender.is_active():
		return in_tex

	# Get the pixels from the input texture
	var img: Image = in_tex.texture.get_image()
	if img == null:
		return in_tex

	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	var rgba: PackedByteArray = img.get_data()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var fps_n: int = get_param_value("fps_n")
	var fps_d: int = get_param_value("fps_d")

	_sender.send_video(rgba, w, h, fps_n, fps_d)

	return in_tex


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _is_ndi_available() -> bool:
	return ClassDB.class_exists(&"GNNDISender")

func _ensure_sender() -> void:
	if _sender != null:
		return
	_sender = ClassDB.instantiate(&"GNNDISender")
	if _sender == null:
		GNLogger.error("NDIOutTOP", "'%s': failed to instantiate GNNDISender" % id)
