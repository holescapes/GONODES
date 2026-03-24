class_name FolderDAT
extends GNDatBase
## Lists files and sub-directories in a given folder path.
## Outputs a table with name, extension, size, modified-date columns.

func _init() -> void:
	node_type = "folder"


## DirAccess directory listing — not available on web.
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios"])


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Directory listing table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("path", "res://", "Path",
		"Directory path to list"))
	add_parameter(GNParameter.create_bool("recursive", false, "Recursive",
		"Include sub-directories recursively"))
	add_parameter(GNParameter.create_string("filter", "*", "Filter",
		"Glob-style filter (e.g. *.png)"))
	add_parameter(GNParameter.create_bool("include_dirs", true, "Include Dirs",
		"Include sub-directories in listing"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var dir_path: String = get_param_value("path").strip_edges()
	var recursive: bool = get_param_value("recursive")
	var filter_pat: String = get_param_value("filter").strip_edges()
	var include_dirs: bool = get_param_value("include_dirs")

	var tbl: GNTableData = _prepare_table(true)
	tbl.set_headers(PackedStringArray(["name", "path", "extension", "size", "is_dir"]))

	if dir_path.is_empty():
		return tbl

	_scan_dir(dir_path, recursive, filter_pat, include_dirs, tbl)
	return tbl


func _scan_dir(path: String, recursive: bool, filter_pat: String,
		include_dirs: bool, tbl: GNTableData) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		GNLogger.warn("FolderDAT", "'%s' — cannot open '%s'" % [id, path])
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path: String = path.path_join(file_name)
		var is_dir: bool = dir.current_is_dir()

		if is_dir:
			if include_dirs:
				tbl.append_row(PackedStringArray([
					file_name, full_path, "", "0", "true"
				]))
			if recursive:
				_scan_dir(full_path, true, filter_pat, include_dirs, tbl)
		else:
			if _matches_filter(file_name, filter_pat):
				var ext: String = file_name.get_extension()
				var size_bytes: String = str(FileAccess.get_file_as_bytes(full_path).size()) if FileAccess.file_exists(full_path) else "0"
				tbl.append_row(PackedStringArray([
					file_name, full_path, ext, size_bytes, "false"
				]))

		file_name = dir.get_next()
	dir.list_dir_end()


func _matches_filter(file_name: String, pattern: String) -> bool:
	if pattern == "*" or pattern.is_empty():
		return true
	return file_name.matchn(pattern)
