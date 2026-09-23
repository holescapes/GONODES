class_name HapOUT
extends GNOutBase
## Encode input texture to a HAP video file for GPU-direct playback.
##
## Captures input TOP texture frames, DXT-compresses them via the native
## GNHapEncoder, and writes them to a QuickTime .mov container.
## The resulting file can be played back by HapInTOP with zero CPU decode.
##
## **Record** = capture/encode frames. Optional **Duration** auto-stops and
## clears Record. Progress / Status update while recording.

var _encoder: RefCounted = null
var _recording: bool = false
var _was_recording: bool = false
var _total_encoded: int = 0
var _target_frames: int = 0
var _last_path: String = ""


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
	add_parameter(GNParameter.create_file("file_path", "user://output/video.mov",
		PackedStringArray(["*.mov"]),
		"File Path", "Output .mov file path",
		GNParameter.FileBrowseMode.SAVE_FILE))
	add_parameter(GNParameter.create_enum("variant",
		PackedStringArray(["HAP (DXT1)", "HAP Alpha (DXT5)", "HAP Q (YCoCg)"]), 0,
		"Variant", "HAP codec variant"))
	add_parameter(GNParameter.create_int("fps", 30, 1, 120,
		"FPS", "Output video framerate"))
	add_parameter(GNParameter.create_float("duration", 0.0, 0.0, 36000.0, 0.1,
		"Duration (sec)",
		"Auto-stop recording after this many seconds (0 = unlimited — stop by turning Record OFF)."))
	add_parameter(GNParameter.create_bool("record", false,
		"Record", "ON = capture/encode frames. Turns OFF automatically when Duration is reached."))
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
		node_warning = "HAP encoding requires the native gn_ext_hap library."
		set_param_value("status", "Failed (no native lib)")
		return null

	var record: bool = get_param_value("record")

	# Falling edge: stop recording and finalize file
	if _was_recording and not record:
		_finish_recording()
	_was_recording = record

	var in_tex: GNTextureData = _get_input_top(inputs, 0)
	if in_tex == null or in_tex.texture == null:
		_sync_status()
		return null

	if not record:
		_sync_status()
		return null

	# Rising edge: start recording
	if record and not _recording:
		var file_path: String = get_param_value("file_path")
		var variant: int = get_param_value("variant")
		var fps: int = get_param_value("fps")
		var dur: float = float(get_param_value("duration"))
		_target_frames = maxi(1, int(round(dur * float(fps)))) if dur > 0.0 else 0

		var out_dir: String = file_path.get_base_dir()
		if not out_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

		var w: int = in_tex.texture.get_width()
		var h: int = in_tex.texture.get_height()
		var global_path: String = ProjectSettings.globalize_path(file_path)
		if not _encoder.start(global_path, w, h, float(fps), variant):
			node_warning = "Failed to start HAP encoding to: " + file_path
			set_param_value("status", "Failed")
			set_param_value("record", false)
			_was_recording = false
			return null

		_recording = true
		_total_encoded = 0
		_last_path = file_path
		node_warning = ""
		set_param_value("progress", 0.0)
		GNLogger.info("HapOUT", "'%s': Recording started → %s (%dx%d)" % [
			id, file_path, w, h])

	# Encode frame (realtime — finalize is the only blocking close)
	if _recording:
		var img: Image = in_tex.texture.get_image()
		if img != null:
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			_encoder.encode_frame(img.get_data())
			_total_encoded += 1
			if _target_frames > 0:
				set_param_value("progress", clampf(
					float(_total_encoded) / float(_target_frames), 0.0, 1.0))
			else:
				set_param_value("progress", clampf(
					1.0 - 1.0 / (1.0 + float(_total_encoded) * 0.01), 0.0, 0.95))
			if _target_frames > 0 and _total_encoded >= _target_frames:
				GNLogger.info("HapOUT",
					"'%s': Duration reached (%d frames) — stopping" % [id, _total_encoded])
				set_param_value("record", false)
				_was_recording = false
				_finish_recording()

	_sync_status()
	return null


func _finish_recording() -> void:
	if not _recording:
		return
	_encoder.finish()
	_recording = false
	set_param_value("progress", 1.0 if _total_encoded > 0 else 0.0)
	GNLogger.info("HapOUT", "'%s': Recording stopped — %d frames → %s" % [
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


func update_preview_control(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		if _recording:
			if _target_frames > 0:
				label.text = "REC ●\n%d/%d" % [_total_encoded, _target_frames]
			else:
				label.text = "REC ● %d frames" % _total_encoded
		elif _total_encoded > 0:
			label.text = "DONE\n%d frames" % _total_encoded
		else:
			label.text = "idle"
