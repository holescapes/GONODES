class_name HapOUT
extends GNOutBase
## Encode input texture to a HAP video file for GPU-direct playback.
##
## Captures input TOP texture frames, DXT-compresses them via the native
## GNHapEncoder, and writes them to a QuickTime .mov container.
## The resulting file can be played back by HapInTOP with zero CPU decode.

var _encoder: RefCounted = null
var _recording: bool = false
var _was_recording: bool = false
var _total_encoded: int = 0


func _init() -> void:
	node_type = "hap_out"
	time_dependent = true
	node_description = "Encode texture to HAP .mov video for GPU-direct playback."
	if ClassDB.class_exists("GNHapEncoder"):
		_encoder = ClassDB.instantiate("GNHapEncoder")


func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Texture to encode")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("file_path", "user://output/video.mov",
		"File Path", "Output .mov file path"))
	add_parameter(GNParameter.create_enum("variant",
		PackedStringArray(["HAP (DXT1)", "HAP Alpha (DXT5)", "HAP Q (YCoCg)"]), 0,
		"Variant", "HAP codec variant"))
	add_parameter(GNParameter.create_int("fps", 30, 1, 120,
		"FPS", "Output video framerate"))
	add_parameter(GNParameter.create_bool("record", false,
		"Record", "Toggle recording on/off"))


func _cook(inputs: Array[GNData]) -> GNData:
	if _encoder == null:
		node_warning = "HAP encoding requires the native gn_ext_hap library."
		return null

	var record: bool = get_param_value("record")

	# Falling edge: stop recording
	if _was_recording and not record:
		_encoder.finish()
		_recording = false
		GNLogger.info("HapOUT", "'%s': Recording stopped — %d frames" % [
			id, _total_encoded])
	_was_recording = record

	# Get input texture
	var in_tex: GNTextureData = _get_input_top(inputs, 0)
	if in_tex == null or in_tex.texture == null:
		return null

	if not record:
		return null

	# Rising edge: start recording
	if record and not _recording:
		var file_path: String = get_param_value("file_path")
		var variant: int = get_param_value("variant")
		var fps: int = get_param_value("fps")

		# Ensure output directory exists
		var out_dir: String = file_path.get_base_dir()
		if not out_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(out_dir)

		var w: int = in_tex.texture.get_width()
		var h: int = in_tex.texture.get_height()

		var global_path: String = ProjectSettings.globalize_path(file_path)
		if not _encoder.start(global_path, w, h, float(fps), variant):
			node_warning = "Failed to start HAP encoding to: " + file_path
			return null

		_recording = true
		_total_encoded = 0
		node_warning = ""
		GNLogger.info("HapOUT", "'%s': Recording started → %s (%dx%d)" % [
			id, file_path, w, h])

	# Encode frame
	if _recording:
		var img: Image = in_tex.texture.get_image()
		if img != null:
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			_encoder.encode_frame(img.get_data())
			_total_encoded += 1

	return null


func update_preview_control(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		if _recording:
			label.text = "REC ● %d frames" % _total_encoded
		elif _total_encoded > 0:
			label.text = "STOPPED\n%d frames" % _total_encoded
		else:
			label.text = "idle"
