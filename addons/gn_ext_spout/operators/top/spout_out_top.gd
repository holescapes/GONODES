class_name SpoutOutTOP
extends GNTopBase
## Share the input texture via Spout2 to other applications (Windows only).
## Creates a named Spout sender that other apps (Resolume, OBS, etc.) can receive.

var _sender: RefCounted = null
var _connected := false
var _prev_name := ""


func _init() -> void:
	node_type = "spoutouttop"
	time_dependent = true
	is_sink = true
	node_description = "Share input texture via Spout2 to external applications (Windows only)."
	if ClassDB.class_exists("GNSpoutSender"):
		_sender = ClassDB.instantiate("GNSpoutSender")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Texture to share via Spout", "In")
	add_output("out", GNFamily.Type.TOP, "Pass-through of input texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("sender_name", "GONODES",
		"Sender Name", "Name visible to Spout receivers."))
	add_parameter(GNParameter.create_bool("active", true, "Active",
		"Enable/disable sending."))


func _cook(inputs: Array[GNData]) -> GNData:
	if _sender == null:
		node_warning = "Spout is only available on Windows with the native library compiled."
		return _passthrough_input(inputs, 0)

	var active: bool = get_param_value("active")
	if not active:
		if _connected:
			_sender.release_sender()
			_connected = false
		return _passthrough_input(inputs, 0)

	var tex_data: GNTextureData = _get_input_top(inputs, 0)
	if tex_data == null or tex_data.texture == null:
		return null

	var sender_name: String = get_param_value("sender_name")
	var w: int = tex_data.resolution.x
	var h: int = tex_data.resolution.y

	# Set or update sender name if changed
	if sender_name != _prev_name:
		_sender.set_sender_name(sender_name)
		_prev_name = sender_name

	# Get pixel data from texture and send via Spout
	var img: Image = tex_data.texture.get_image()
	if img == null:
		return _passthrough_input(inputs, 0)

	img.convert(Image.FORMAT_RGBA8)
	var rgba: PackedByteArray = img.get_data()

	_sender.send_image(rgba, w, h, false)

	# Pass through input
	return tex_data


func _passthrough_input(inputs: Array[GNData], idx: int) -> GNData:
	if idx < inputs.size() and inputs[idx] != null:
		return inputs[idx]
	return null


func _on_node_removed() -> void:
	if _sender != null and _connected:
		_sender.release_sender()
		_connected = false
