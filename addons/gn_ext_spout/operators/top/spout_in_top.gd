class_name SpoutInTOP
extends GNTopBase
## Receive a shared GPU texture from another Spout sender (Windows only).
## Lists active senders and receives RGBA pixel data each frame.

var _receiver: RefCounted = null
var _connected := false


func _init() -> void:
	node_type = "spoutintop"
	time_dependent = true
	node_description = "Receive shared texture via Spout2 from external applications (Windows only)."
	if ClassDB.class_exists("GNSpoutReceiver"):
		_receiver = ClassDB.instantiate("GNSpoutReceiver")


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Received texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("sender_name", "Sender Name", "Sender Name",
		"Spout sender name to receive from. Empty = active sender."))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(1920, 1080),
		"Resolution", "Expected resolution (auto-updates from sender)."))


func _cook(inputs: Array[GNData]) -> GNData:
	if _receiver == null:
		node_warning = "Spout is only available on Windows with the native library compiled."
		return null

	var sender_name: String = get_param_value("sender_name")

	if not _connected:
		if not _receiver.create_receiver(sender_name):
			node_warning = "Failed to create Spout receiver."
			return null
		_connected = true

	var rgba: PackedByteArray = _receiver.receive_image()
	if rgba.is_empty():
		return null

	var w: int = _receiver.get_width()
	var h: int = _receiver.get_height()
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
	if _receiver != null and _connected:
		_receiver.release_receiver()
		_connected = false
