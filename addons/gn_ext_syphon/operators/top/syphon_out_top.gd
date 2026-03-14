class_name SyphonOutTOP
extends GNTopBase
## Share the input texture via Syphon to other applications (macOS only).
## Creates a named Syphon server that other apps (VDMX, MadMapper, etc.) can receive.

var _server: RefCounted = null
var _prev_name := ""


func _init() -> void:
	node_type = "syphonouttop"
	time_dependent = true
	is_sink = true
	node_description = "Share input texture via Syphon to external applications (macOS only)."
	if ClassDB.class_exists("GNSyphonServer"):
		_server = ClassDB.instantiate("GNSyphonServer")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Texture to share via Syphon")
	add_output("out", GNFamily.Type.TOP, "Pass-through of input texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("server_name", "GONODES",
		"Server Name", "Name visible to Syphon clients."))
	add_parameter(GNParameter.create_bool("active", true, "Active",
		"Enable/disable output."))


func _cook(inputs: Array[GNData]) -> GNData:
	if _server == null:
		node_warning = "Syphon is only available on macOS with the native library compiled."
		return _passthrough_input(inputs, 0)

	var active: bool = get_param_value("active")
	if not active:
		_server.stop()
		return _passthrough_input(inputs, 0)

	var tex_data: GNTextureData = _get_input_top(inputs, 0)
	if tex_data == null or tex_data.texture == null:
		return null

	var server_name: String = get_param_value("server_name")
	var w: int = tex_data.resolution.x
	var h: int = tex_data.resolution.y

	# Set or update server name if changed
	if server_name != _prev_name:
		_server.set_server_name(server_name)
		_prev_name = server_name

	# Get pixel data from texture and publish via Syphon
	var img: Image = tex_data.texture.get_image()
	if img == null:
		return _passthrough_input(inputs, 0)

	img.convert(Image.FORMAT_RGBA8)
	var rgba: PackedByteArray = img.get_data()

	_server.publish_image(rgba, w, h)

	# Pass through input
	return tex_data


func _passthrough_input(inputs: Array[GNData], idx: int) -> GNData:
	if idx < inputs.size() and inputs[idx] != null:
		return inputs[idx]
	return null


func _on_node_removed() -> void:
	if _server != null:
		_server.stop()
