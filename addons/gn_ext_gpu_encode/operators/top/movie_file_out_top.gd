class_name MovieFileOutTOP
extends GNTopBase
## Record input texture to a video file using hardware GPU encoding.
## Uses Media Foundation (Windows) or VideoToolbox (macOS) for H.264 encoding.

var _encoder: RefCounted = null
var _recording := false


func _init() -> void:
	node_type = "moviefileouttop"
	time_dependent = true
	is_sink = true
	node_description = "Record input texture to MP4 video via GPU encoding."
	if ClassDB.class_exists("GNGpuEncoder"):
		_encoder = ClassDB.instantiate("GNGpuEncoder")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Texture to encode to video")
	add_output("out", GNFamily.Type.TOP, "Pass-through of input texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("file_path", "output.mp4",
		"File Path", "Output video file path (.mp4)."))
	add_parameter(GNParameter.create_int("bitrate", 8000, 500, 100000, "Bitrate (kbps)",
		"Encoding bitrate in kilobits per second."))
	add_parameter(GNParameter.create_int("fps", 30, 1, 120, "FPS",
		"Output video framerate."))
	add_parameter(GNParameter.create_bool("record", false, "Record",
		"Toggle recording on/off."))


func _cook(inputs: Array[GNData]) -> GNData:
	if _encoder == null:
		node_warning = "GPU encoding requires the native gn_ext_gpu_encode library."
		return _passthrough_input(inputs, 0)

	var record: bool = get_param_value("record")

	# Stop recording
	if not record and _recording:
		_encoder.finish()
		_recording = false
		return _passthrough_input(inputs, 0)

	if not record:
		return _passthrough_input(inputs, 0)

	var tex_data: GNTextureData = _get_input_top(inputs, 0)
	if tex_data == null or tex_data.texture == null:
		return null

	var w: int = tex_data.resolution.x
	var h: int = tex_data.resolution.y

	# Start recording
	if record and not _recording:
		var file_path: String = get_param_value("file_path")
		var bitrate: int = get_param_value("bitrate")
		var fps: int = get_param_value("fps")

		if not _encoder.start(file_path, w, h, fps, bitrate):
			node_warning = "Failed to start GPU encoding. Check file path and codec support."
			return _passthrough_input(inputs, 0)
		_recording = true

	# Encode frame
	if _recording:
		var img: Image = tex_data.texture.get_image()
		if img != null:
			img.convert(Image.FORMAT_RGBA8)
			var rgba: PackedByteArray = img.get_data()
			_encoder.encode_frame(rgba)

	return tex_data


func _passthrough_input(inputs: Array[GNData], idx: int) -> GNData:
	if idx < inputs.size() and inputs[idx] != null:
		return inputs[idx]
	return null


func _on_node_removed() -> void:
	if _encoder != null and _recording:
		_encoder.finish()
		_recording = false
