class_name TextureSaveOUT
extends GNOutBase
## Reads a GPU texture back to CPU and saves to disk as PNG, WebP, or EXR.
##
## Activate the "active" toggle to start writing.
## Supports auto-numbering for image sequences.
## The GPU→CPU readback (`get_image()`) happens once per cook when active.

enum Format { PNG, WEBP, EXR }

## Running frame counter for auto-numbering.
var _frame_counter: int = 0

## Previous "active" state — reset counter on re-activation.
var _was_active: bool = false


func _init() -> void:
	node_type = "texture_save"
	node_description = "Save GPU texture to disk (PNG, WebP, EXR). GPU→CPU readback + file write."


## Disk write — not available on web.
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Texture to save")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "When enabled, saves the texture to disk every cook"))
	add_parameter(GNParameter.create_string("file_path", "user://output/frame",
		"File Path", "Base file path (without extension). Directory is created automatically."))
	add_parameter(GNParameter.create_enum("format",
		PackedStringArray(["PNG", "WebP", "EXR"]), 0,
		"Format", "Output image format"))
	add_parameter(GNParameter.create_float("quality", 0.75, 0.0, 1.0, 0.01,
		"Quality", "WebP lossy quality (0-1). Ignored for PNG/EXR."))
	add_parameter(GNParameter.create_bool("auto_number", true,
		"Auto Number", "Append _NNNN frame counter to filename"))
	add_parameter(GNParameter.create_int("start_frame", 0, 0, null,
		"Start Frame", "Starting frame number for auto-numbering"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null or tex_in.texture == null:
		return null

	var active: bool = get_param_value("active")

	# Reset counter on re-activation
	if active and not _was_active:
		_frame_counter = get_param_value("start_frame")
	_was_active = active

	if not active:
		return null

	# GPU → CPU readback
	var image: Image = tex_in.texture.get_image()
	if image == null:
		GNLogger.warn("TextureSaveOUT",
			"'%s': get_image() returned null (texture may not be ready)" % id)
		return null

	# Build path
	var base_path: String = get_param_value("file_path")
	var fmt: int = get_param_value("format")
	var auto_num: bool = get_param_value("auto_number")

	var full_path: String = base_path
	if auto_num:
		full_path += "_%04d" % _frame_counter
		_frame_counter += 1

	match fmt:
		Format.PNG:  full_path += ".png"
		Format.WEBP: full_path += ".webp"
		Format.EXR:  full_path += ".exr"

	# Ensure directory
	var dir_path: String = full_path.get_base_dir()
	if not dir_path.is_empty():
		DirAccess.make_dir_recursive_absolute(dir_path)

	# Save
	var err: Error = OK
	match fmt:
		Format.PNG:
			err = image.save_png(full_path)
		Format.WEBP:
			var quality: float = get_param_value("quality")
			err = image.save_webp(full_path, quality < 1.0, quality)
		Format.EXR:
			err = image.save_exr(full_path, false)

	if err != OK:
		GNLogger.warn("TextureSaveOUT",
			"'%s': Failed to save '%s' (error %d)" % [id, full_path, err])
	else:
		GNLogger.debug("TextureSaveOUT", "'%s': Saved '%s'" % [id, full_path])

	return null
