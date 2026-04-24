class_name SyphonInTOP
extends GNTopBase
## Receive a shared GPU texture from a Syphon server (macOS only).
## Lists active servers and receives RGBA pixel data each frame.

var _client: RefCounted = null
var _connected := false


func _init() -> void:
	node_type = "syphonintop"
	time_dependent = true
	node_description = "Receive shared texture via Syphon from external applications (macOS only)."
	if ClassDB.class_exists("GNSyphonClient"):
		_client = ClassDB.instantiate("GNSyphonClient")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Received texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("app_name", "App Name", "App Name",
		"Syphon server application name. Empty = first available."))
	add_parameter(GNParameter.create_string("server_name", "Server Name", "Server Name",
		"Syphon server name. Empty = first available."))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(1920, 1080),
		"Resolution", "Expected resolution (auto-updates from server)."))


func _cook(inputs: Array[GNData]) -> GNData:
	if _client == null:
		node_warning = "Syphon is only available on macOS with the native library compiled."
		return null

	var app_name: String = get_param_value("app_name")
	var server_name: String = get_param_value("server_name")

	if not _connected:
		if not _client.connect_to_server(app_name, server_name):
			node_warning = "Failed to connect to Syphon server."
			return null
		_connected = true

	var rgba: PackedByteArray = _client.receive_image()
	if rgba.is_empty():
		return null

	var w: int = _client.get_width()
	var h: int = _client.get_height()
	if w <= 0 or h <= 0:
		return null

	# Create Image from received RGBA data and upload to GPU
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba)
	var tex := ImageTexture.create_from_image(img)

	var out := GNTextureData.new()
	out.texture = tex
	out.resolution = Vector2i(w, h)
	return out


func _on_node_removed() -> void:
	if _client != null and _connected:
		_client.disconnect_from_server()
		_connected = false
