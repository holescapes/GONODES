class_name FileCopyOUT
extends GNOutBase
## Copies a file from source_path to dest_path on a rising-edge pulse of Active.
##
## Used to seed exhibition day folders (e.g. copy display/picK.png →
## modified/dayN/picK.png when the day file is missing).  Writes via a temp
## file + rename when possible for crash safety.

## Previous active state for rising-edge detection.
var _was_active: bool = false

## Last copy result message for preview / debug.
var _last_status: String = ""


func _init() -> void:
	node_type = "file_copy"


## Disk IO — not available on web.
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios"])


func _init_ports() -> void:
	# No data ports — path-driven utility sink.
	pass


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "Pulse / rising edge: perform one copy, then leave ON or toggle"))
	add_parameter(GNParameter.create_file("source", "",
		PackedStringArray(["*.png", "*.jpg", "*.jpeg", "*.webp", "*.*"]),
		"Source", "File to copy from (any path tier)",
		GNParameter.FileBrowseMode.OPEN_FILE))
	add_parameter(GNParameter.create_file("dest", "",
		PackedStringArray(["*.png", "*.jpg", "*.jpeg", "*.webp", "*.*"]),
		"Dest", "Destination file path",
		GNParameter.FileBrowseMode.SAVE_FILE))
	add_parameter(GNParameter.create_bool("overwrite", true,
		"Overwrite", "Replace destination if it already exists"))
	add_parameter(GNParameter.create_bool("make_dirs", true,
		"Make Dirs", "Create destination parent directories if missing"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var active: bool = get_param_value("active")
	var rising: bool = active and not _was_active
	_was_active = active

	if not rising:
		return null

	var src_raw: String = str(get_param_value("source")).strip_edges()
	var dst_raw: String = str(get_param_value("dest")).strip_edges()
	var overwrite: bool = get_param_value("overwrite")
	var make_dirs: bool = get_param_value("make_dirs")

	var src := GNResourceLoader.resolve(src_raw, project_dir)
	var dst := GNResourceLoader.resolve(dst_raw, project_dir)
	if src.is_empty():
		src = src_raw
	if dst.is_empty():
		dst = dst_raw

	var err := copy_file(src, dst, overwrite, make_dirs)
	if err != OK:
		_last_status = "error %d" % err
		node_warning = "Copy failed (%d): %s → %s" % [err, src, dst]
		GNLogger.warn("FileCopyOUT", "'%s' — %s" % [id, node_warning])
	else:
		_last_status = "ok"
		node_warning = ""
		GNLogger.info("FileCopyOUT", "'%s' — copied %s → %s" % [id, src, dst])
	return null


## Static helper used by unit tests and SCRIPT callers.
static func copy_file(src: String, dst: String, overwrite: bool = true,
		make_dirs: bool = true) -> Error:
	if src.is_empty() or dst.is_empty():
		return ERR_INVALID_PARAMETER
	if not FileAccess.file_exists(src):
		return ERR_FILE_NOT_FOUND
	if src == dst:
		return OK
	if FileAccess.file_exists(dst) and not overwrite:
		return ERR_ALREADY_EXISTS

	var dir_path: String = dst.get_base_dir()
	if make_dirs and not dir_path.is_empty():
		var mk := DirAccess.make_dir_recursive_absolute(dir_path)
		if mk != OK and mk != ERR_ALREADY_EXISTS:
			return mk

	# Atomic-ish: write to temp beside dest, then rename.
	var tmp: String = dst + ".tmp_gonodes"
	var src_f := FileAccess.open(src, FileAccess.READ)
	if src_f == null:
		return FileAccess.get_open_error()
	var src_len: int = src_f.get_length() as int
	var bytes: PackedByteArray = src_f.get_buffer(src_len)
	src_f.close()
	if bytes.size() != src_len:
		return ERR_FILE_CANT_READ
	var out := FileAccess.open(tmp, FileAccess.WRITE)
	if out == null:
		return FileAccess.get_open_error()
	out.store_buffer(bytes)
	out.close()

	if FileAccess.file_exists(dst):
		DirAccess.remove_absolute(dst)
	var ren := DirAccess.rename_absolute(tmp, dst)
	if ren != OK:
		# Fallback: copy temp contents failed rename — try direct store
		if FileAccess.file_exists(tmp):
			var out2 := FileAccess.open(dst, FileAccess.WRITE)
			if out2 == null:
				DirAccess.remove_absolute(tmp)
				return FileAccess.get_open_error()
			out2.store_buffer(FileAccess.get_file_as_bytes(tmp))
			out2.close()
			DirAccess.remove_absolute(tmp)
			return OK
		return ren
	return OK


func get_preview_text() -> String:
	if _last_status.is_empty():
		return "idle"
	return _last_status
