class_name ImageSaveOUT
extends GNOutBase
## Saves a CPU-side Image to disk as PNG, WebP, or EXR.
##
## Activate the "active" toggle to start writing (sync on the cook thread).
## Supports optional auto-numbering (e.g. frame_0001.png).
## For long numbered sequences prefer MovieOUT; for video containers use FFmpegOUT.
## For GPU textures use TextureSaveOUT.

enum Format { PNG, WEBP, EXR }

## Running frame counter for auto-numbering.
var _frame_counter: int = 0

## Last "active" state — used to reset counter on re-activation.
var _was_active: bool = false


func _init() -> void:
	node_type = "image_save"


## Disk write — not available on web.
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.IMG, false, "Image to save")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", false,
		"Active",
		"When enabled, saves the image to disk every cook (sync write — use MovieOUT for long sequences)"))
	add_parameter(GNParameter.create_file("file_path", "user://output/frame",
		PackedStringArray(["*.png", "*.webp", "*.exr"]),
		"File Path",
		"Base output path (Format extension is appended; existing extension is stripped).",
		GNParameter.FileBrowseMode.SAVE_FILE))
	add_parameter(GNParameter.create_enum("format",
		PackedStringArray(["PNG", "WebP", "EXR"]), 0,
		"Format", "Output image format (PNG, WebP, or EXR)"))
	add_parameter(GNParameter.create_float("quality", 0.75, 0.0, 1.0, 0.01,
		"Quality", "WebP lossy quality (0-1). Ignored for PNG/EXR."))
	add_parameter(GNParameter.create_bool("auto_number", true,
		"Auto Number",
		"Append _NNNN frame counter. OFF = overwrite the same path each cook."))
	add_parameter(GNParameter.create_int("start_frame", 0, 0, null,
		"Start Frame", "Starting frame number when Auto Number is on (resets on re-activation)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var img_in: GNImageData = _get_input_img(inputs, 0)
	if img_in == null or img_in.image == null:
		return null

	var active: bool = get_param_value("active")

	# Reset frame counter when toggling active on
	if active and not _was_active:
		_frame_counter = get_param_value("start_frame")
	_was_active = active

	if not active:
		return null

	# Build the full save path (strip any picked extension so Format can append)
	var base_path: String = str(get_param_value("file_path")).get_basename()
	var fmt: int = get_param_value("format")
	var auto_num: bool = get_param_value("auto_number")

	var full_path: String = base_path
	if auto_num:
		full_path += "_%04d" % _frame_counter
		_frame_counter += 1

	# Append extension
	match fmt:
		Format.PNG:  full_path += ".png"
		Format.WEBP: full_path += ".webp"
		Format.EXR:  full_path += ".exr"

	# Ensure directory exists
	var dir_path: String = full_path.get_base_dir()
	if not dir_path.is_empty():
		DirAccess.make_dir_recursive_absolute(dir_path)

	# Save
	var err: Error = OK
	match fmt:
		Format.PNG:
			err = img_in.image.save_png(full_path)
		Format.WEBP:
			var quality: float = get_param_value("quality")
			err = img_in.image.save_webp(full_path, quality < 1.0, quality)
		Format.EXR:
			err = img_in.image.save_exr(full_path, false)

	if err != OK:
		GNLogger.warn("ImageSaveOUT", "'%s': Failed to save '%s' (error %d)" % [id, full_path, err])
	else:
		GNLogger.debug("ImageSaveOUT", "'%s': Saved '%s'" % [id, full_path])

	return null
