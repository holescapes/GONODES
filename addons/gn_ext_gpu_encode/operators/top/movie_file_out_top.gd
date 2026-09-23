class_name MovieFileOutTOP
extends GNTopBase
## Record input texture to a video file using hardware GPU encoding.
## Uses Media Foundation (Windows) or VideoToolbox (macOS) for H.264 encoding.
##
## **Record** = capture/encode frames. Optional **Duration** auto-stops and
## clears Record. Progress / Status update while recording.

var _encoder: RefCounted = null
var _recording := false
var _was_recording := false
var _total_encoded: int = 0
var _target_frames: int = 0
var _last_path: String = ""


func _init() -> void:
	node_type = "moviefileouttop"
	time_dependent = true
	is_sink = true
	node_description = "Record input texture to MP4 video via GPU encoding."
	if ClassDB.class_exists("GNGpuEncoder"):
		_encoder = ClassDB.instantiate("GNGpuEncoder")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Texture to encode to video", "In")
	add_output("out", GNFamily.Type.TOP, "Pass-through of input texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("file_path", "user://output/video.mp4",
		PackedStringArray(["*.mp4"]),
		"File Path", "Output video file path (.mp4).",
		GNParameter.FileBrowseMode.SAVE_FILE))
	add_parameter(GNParameter.create_int("bitrate", 8000, 500, 100000, "Bitrate (kbps)",
		"Encoding bitrate in kilobits per second."))
	add_parameter(GNParameter.create_int("fps", 30, 1, 120, "FPS",
		"Output video framerate."))
	add_parameter(GNParameter.create_float("duration", 0.0, 0.0, 36000.0, 0.1,
		"Duration (sec)",
		"Auto-stop recording after this many seconds (0 = unlimited — stop by turning Record OFF)."))
	add_parameter(GNParameter.create_bool("record", false, "Record",
		"ON = capture/encode frames. Turns OFF automatically when Duration is reached."))
	var status_p := GNParameter.create_string("status", "Idle", "Status",
		"Idle / Recording / Done / Failed")
	status_p.read_only = true
	add_parameter(status_p)
	var prog_p := GNParameter.create_float("progress", 0.0, 0.0, 1.0, 0.01,
		"Progress", "Recording progress (0–1); based on Duration when set")
	prog_p.read_only = true
	add_parameter(prog_p)


func _pre_cook(delta: float) -> void:
	is_sink = bool(get_param_value("record")) or _recording
	super._pre_cook(delta)


func _cook(inputs: Array[GNData]) -> GNData:
	if _encoder == null:
		node_warning = "GPU encoding requires the native gn_ext_gpu_encode library."
		set_param_value("status", "Failed (no native lib)")
		return _passthrough_input(inputs, 0)

	var record: bool = get_param_value("record")

	if _was_recording and not record:
		_finish_recording()
	_was_recording = record

	if not record:
		_sync_status()
		return _passthrough_input(inputs, 0)

	var tex_data: GNTextureData = _get_input_top(inputs, 0)
	if tex_data == null or tex_data.texture == null:
		_sync_status()
		return null

	var w: int = tex_data.resolution.x
	var h: int = tex_data.resolution.y

	if record and not _recording:
		var file_path: String = get_param_value("file_path")
		var bitrate: int = get_param_value("bitrate")
		var fps: int = get_param_value("fps")
		var dur: float = float(get_param_value("duration"))
		_target_frames = maxi(1, int(round(dur * float(fps)))) if dur > 0.0 else 0

		var out_dir: String = str(file_path).get_base_dir()
		if not out_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

		var global_path: String = ProjectSettings.globalize_path(file_path)
		if not _encoder.start(global_path, w, h, fps, bitrate):
			node_warning = "Failed to start GPU encoding. Check file path and codec support."
			set_param_value("status", "Failed")
			set_param_value("record", false)
			_was_recording = false
			return _passthrough_input(inputs, 0)
		_recording = true
		_total_encoded = 0
		_last_path = file_path
		node_warning = ""
		set_param_value("progress", 0.0)
		GNLogger.info("MovieFileOutTOP", "'%s': Recording started → %s" % [id, file_path])

	if _recording:
		var img: Image = tex_data.texture.get_image()
		if img != null:
			img.convert(Image.FORMAT_RGBA8)
			var rgba: PackedByteArray = img.get_data()
			_encoder.encode_frame(rgba)
			_total_encoded += 1
			if _target_frames > 0:
				set_param_value("progress", clampf(
					float(_total_encoded) / float(_target_frames), 0.0, 1.0))
			else:
				set_param_value("progress", clampf(
					1.0 - 1.0 / (1.0 + float(_total_encoded) * 0.01), 0.0, 0.95))
			if _target_frames > 0 and _total_encoded >= _target_frames:
				GNLogger.info("MovieFileOutTOP",
					"'%s': Duration reached (%d frames) — stopping" % [id, _total_encoded])
				set_param_value("record", false)
				_was_recording = false
				_finish_recording()

	_sync_status()
	return tex_data


func _finish_recording() -> void:
	if not _recording:
		return
	_encoder.finish()
	_recording = false
	set_param_value("progress", 1.0 if _total_encoded > 0 else 0.0)
	GNLogger.info("MovieFileOutTOP", "'%s': Recording stopped — %d frames → %s" % [
		id, _total_encoded, _last_path])


func _sync_status() -> void:
	if _recording:
		if _target_frames > 0:
			set_param_value("status", "Recording %d / %d" % [_total_encoded, _target_frames])
		else:
			set_param_value("status", "Recording %d frames" % _total_encoded)
	elif _total_encoded > 0:
		set_param_value("status", "Done → %s" % _last_path.get_file())
	else:
		set_param_value("status", "Idle")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _encoder != null and _recording:
			_encoder.finish()
			_recording = false


func _passthrough_input(inputs: Array[GNData], idx: int) -> GNData:
	if idx < inputs.size() and inputs[idx] != null:
		return inputs[idx]
	return null
