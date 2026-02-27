class_name FFmpegOutIMG
extends GNImgBase
## Encodes an IMG image sequence into a video file using the FFmpeg CLI.
##
## **Requires `ffmpeg` on the system PATH.**  If FFmpeg is not found, the
## operator logs a warning and does nothing.
##
## Workflow:
##   1. Set output path, codec, framerate, quality.
##   2. Toggle "active" ON → frames accumulate to a temp folder.
##   3. Toggle "active" OFF → FFmpeg encodes the temp frames into a video.
##   4. Temp frames are cleaned up after a successful encode.
##
## This is a **sink** operator (`is_sink = true`).
##
## Supported codecs:
##   - H.264 (.mp4) — best compatibility
##   - H.265 (.mp4) — better compression, slower
##   - VP9 (.webm) — open codec, good quality
##   - ProRes (.mov) — production quality, large files

enum Codec { H264, H265, VP9, PRORES }

## Temp directory for intermediate frames.
var _temp_dir: String = ""

## Frame counter for temp frames.
var _frame_counter: int = 0

## Previous "active" state — encode on falling edge.
var _was_active: bool = false

## Total frames captured this recording session.
var _total_captured: int = 0

## Whether we're currently encoding (for preview status).
var _encoding: bool = false

## Whether ffmpeg was found on PATH.
var _ffmpeg_available: bool = false
var _ffmpeg_checked: bool = false


func _init() -> void:
	node_type = "ffmpegoutimg"
	is_sink = true
	node_description = "Encode IMG sequence to video via FFmpeg CLI (H.264, H.265, VP9, ProRes)."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "Image frames to encode")
	# No output — this is a file sink.


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "When ON, captures frames. When turned OFF, encodes to video."))
	add_parameter(GNParameter.create_string("output_file", "user://output/video",
		"Output File", "Output video path (without extension — set by codec)"))
	add_parameter(GNParameter.create_enum("codec",
		PackedStringArray(["H.264 (.mp4)", "H.265 (.mp4)", "VP9 (.webm)", "ProRes (.mov)"]), 0,
		"Codec", "Video codec for encoding"))
	add_parameter(GNParameter.create_int("framerate", 30, 1, 120,
		"Framerate", "Output video frame rate"))
	add_parameter(GNParameter.create_int("crf", 23, 0, 51,
		"Quality (CRF)", "Constant Rate Factor (0=lossless, 23=default, 51=worst). Lower is better."))


func _cook(inputs: Array[GNData]) -> GNData:
	var img_in: GNImageData = _get_input_img(inputs, 0)
	if img_in == null or img_in.image == null:
		return img_in

	# Pass-through for preview
	var out := _prepare_image()
	out.set_image(img_in.image)

	# Check FFmpeg availability (once)
	if not _ffmpeg_checked:
		_ffmpeg_checked = true
		_ffmpeg_available = _check_ffmpeg()
		if not _ffmpeg_available:
			GNLogger.warn("FFmpegOutIMG",
				"'%s': ffmpeg not found on PATH. Video encoding unavailable." % id)

	var active: bool = get_param_value("active")

	# Falling edge: active was ON, now OFF → encode
	if _was_active and not active:
		if _ffmpeg_available and _total_captured > 0:
			_encode_video()
		elif not _ffmpeg_available:
			GNLogger.warn("FFmpegOutIMG",
				"'%s': Cannot encode — ffmpeg not on PATH" % id)
		_was_active = false
		return out

	# Rising edge: activate → set up temp dir
	if active and not _was_active:
		_frame_counter = 0
		_total_captured = 0
		_temp_dir = _create_temp_dir()
		GNLogger.info("FFmpegOutIMG",
			"'%s': Recording started → %s" % [id, _temp_dir])

	_was_active = active

	if not active:
		return out

	if not _ffmpeg_available:
		return out

	# Save frame to temp dir as PNG (lossless intermediate)
	var frame_path: String = _temp_dir.path_join("frame_%06d.png" % _frame_counter)
	var err: Error = img_in.image.save_png(frame_path)
	if err == OK:
		_frame_counter += 1
		_total_captured += 1
	else:
		GNLogger.warn("FFmpegOutIMG",
			"'%s': Failed to save temp frame (error %d)" % [id, err])

	return out


# ─── FFmpeg Helpers ────────────────────────────────────────────────────────────

## Check if ffmpeg is available on the system PATH.
func _check_ffmpeg() -> bool:
	var output: Array = []
	var exit_code: int = OS.execute("ffmpeg", ["-version"], output, true)
	return exit_code == 0


## Create a unique temp directory for this recording session.
func _create_temp_dir() -> String:
	var base: String = OS.get_user_data_dir().path_join("gonodes_ffmpeg_temp")
	var session_dir: String = base.path_join("session_%d" % Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(session_dir)
	return session_dir


## Run ffmpeg to encode the captured frames into a video file.
func _encode_video() -> void:
	_encoding = true

	var output_base: String = get_param_value("output_file")
	var codec_idx: int = get_param_value("codec")
	var fps: int = get_param_value("framerate")
	var crf: int = get_param_value("crf")

	# Build ffmpeg command
	var input_pattern: String = _temp_dir.path_join("frame_%06d.png")
	var extension: String = ""
	var codec_args: PackedStringArray = PackedStringArray()

	match codec_idx:
		Codec.H264:
			extension = ".mp4"
			codec_args = PackedStringArray([
				"-c:v", "libx264", "-crf", str(crf), "-pix_fmt", "yuv420p"])
		Codec.H265:
			extension = ".mp4"
			codec_args = PackedStringArray([
				"-c:v", "libx265", "-crf", str(crf), "-pix_fmt", "yuv420p"])
		Codec.VP9:
			extension = ".webm"
			codec_args = PackedStringArray([
				"-c:v", "libvpx-vp9", "-crf", str(crf), "-b:v", "0",
				"-pix_fmt", "yuv420p"])
		Codec.PRORES:
			extension = ".mov"
			codec_args = PackedStringArray([
				"-c:v", "prores_ks", "-profile:v", "3", "-pix_fmt", "yuv422p10le"])

	var output_path: String = output_base + extension

	# Ensure output directory
	var out_dir: String = output_path.get_base_dir()
	if not out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(out_dir)

	# Build full args
	var args: PackedStringArray = PackedStringArray([
		"-y",  # overwrite
		"-framerate", str(fps),
		"-i", ProjectSettings.globalize_path(input_pattern),
	])
	args.append_array(codec_args)
	args.append(ProjectSettings.globalize_path(output_path))

	GNLogger.info("FFmpegOutIMG",
		"'%s': Encoding %d frames → '%s'" % [id, _total_captured, output_path])

	var output: Array = []
	var exit_code: int = OS.execute("ffmpeg", args, output, true)

	if exit_code == 0:
		GNLogger.info("FFmpegOutIMG",
			"'%s': Encoding complete → '%s'" % [id, output_path])
		# Clean up temp frames
		_cleanup_temp_dir()
	else:
		GNLogger.warn("FFmpegOutIMG",
			"'%s': FFmpeg exited with code %d. Temp frames kept at '%s'" % [
				id, exit_code, _temp_dir])
		if output.size() > 0:
			GNLogger.warn("FFmpegOutIMG", "FFmpeg output: %s" % str(output[0]).substr(0, 500))

	_encoding = false


## Remove temporary frame files and directory.
func _cleanup_temp_dir() -> void:
	if _temp_dir.is_empty():
		return
	var dir := DirAccess.open(_temp_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	# Remove the session directory itself
	DirAccess.remove_absolute(_temp_dir)
	_temp_dir = ""


## Override preview to show recording/encoding status.
func update_preview_control(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		if not _ffmpeg_available and _ffmpeg_checked:
			label.text = "no ffmpeg"
		elif _encoding:
			label.text = "ENCODING..."
		elif get_param_value("active"):
			label.text = "REC ● %d" % _total_captured
		elif _total_captured > 0:
			label.text = "DONE\n%d frames" % _total_captured
		else:
			label.text = "idle"
