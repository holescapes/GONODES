class_name MovieOUT
extends GNOutBase
## Saves an IMG image sequence to disk as numbered frames (PNG or WebP).
##
## When "active" is on, each cook saves the input Image as a numbered file.
## Use this for frame-by-frame image sequence export.
##
## For video container encoding, use FFmpegOUT instead (requires
## EIRTeam.FFmpeg GDExtension).
##
## Workflow:
##   NoiseTOP → TOPtoIMG → MovieOUT  (GPU → CPU → disk)
##   ScriptIMG → MovieOUT             (CPU → disk directly)

enum Format { PNG, WEBP }

## Running frame counter.
var _frame_counter: int = 0

## Previous "active" state for reset-on-reactivation.
var _was_active: bool = false

## Total frames written this session (for preview label).
var _total_written: int = 0


func _init() -> void:
	node_type = "movie_out"
	node_description = "Save image sequence to disk (numbered PNG/WebP frames)."


## Disk write — not available on web.
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "Image to save as frame")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "When enabled, saves each input image as a numbered frame"))
	add_parameter(GNParameter.create_string("output_folder", "user://output/sequence",
		"Output Folder", "Folder for frame files. Created automatically."))
	add_parameter(GNParameter.create_string("file_prefix", "frame",
		"File Prefix", "Filename prefix before the frame number"))
	add_parameter(GNParameter.create_enum("format",
		PackedStringArray(["PNG", "WebP"]), 0,
		"Format", "Image format for each frame"))
	add_parameter(GNParameter.create_float("quality", 0.9, 0.0, 1.0, 0.01,
		"Quality", "WebP quality (0-1). Ignored for PNG."))
	add_parameter(GNParameter.create_int("start_frame", 0, 0, null,
		"Start Frame", "Starting frame number"))
	add_parameter(GNParameter.create_int("frame_padding", 4, 1, 8,
		"Frame Padding", "Number of digits in frame number (e.g. 4 → frame_0001)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var img_in: GNImageData = _get_input_img(inputs, 0)
	if img_in == null or img_in.image == null:
		return null

	var active: bool = get_param_value("active")

	# Reset on re-activation
	if active and not _was_active:
		_frame_counter = get_param_value("start_frame")
		_total_written = 0
	_was_active = active

	if not active:
		return null

	# Build path: folder/prefix_NNNN.ext
	var folder: String = get_param_value("output_folder")
	var prefix: String = get_param_value("file_prefix")
	var fmt: int = get_param_value("format")
	var padding: int = get_param_value("frame_padding")

	# Ensure folder
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)

	var frame_str: String = str(_frame_counter).pad_zeros(padding)
	var extension: String = ".png" if fmt == Format.PNG else ".webp"
	var full_path: String = folder.path_join("%s_%s%s" % [prefix, frame_str, extension])

	# Save
	var err: Error = OK
	match fmt:
		Format.PNG:
			err = img_in.image.save_png(full_path)
		Format.WEBP:
			var quality: float = get_param_value("quality")
			err = img_in.image.save_webp(full_path, quality < 1.0, quality)

	if err != OK:
		GNLogger.warn("MovieOUT",
			"'%s': Failed to save frame '%s' (error %d)" % [id, full_path, err])
	else:
		_total_written += 1
		_frame_counter += 1

	return null


## Override preview to show recording status.
func update_preview_control(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		var active: bool = get_param_value("active")
		if active:
			label.text = "REC ● %d frames" % _total_written
		elif _total_written > 0:
			label.text = "STOPPED\n%d frames" % _total_written
		else:
			label.text = "idle"
