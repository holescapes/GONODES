class_name FolderDAT
extends GNDatBase
## Lists files and sub-directories in a given folder path.
## Outputs a table with name, path, extension, size, is_dir columns.
## Supports project:// path tiers and optional name/modified sorting.

func _init() -> void:
	node_type = "folder"


## DirAccess directory listing — not available on web.
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios"])


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Directory listing table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_folder("path", "res://", "Path",
		"Directory path to list (supports project://)"))
	add_parameter(GNParameter.create_bool("recursive", false, "Recursive",
		"Include sub-directories recursively"))
	add_parameter(GNParameter.create_string("filter", "*", "Filter",
		"Glob-style filter (e.g. *.png)"))
	add_parameter(GNParameter.create_bool("include_dirs", true, "Include Dirs",
		"Include sub-directories in listing"))
	add_parameter(GNParameter.create_enum("sort",
		PackedStringArray(["Name", "Modified"]), 0,
		"Sort", "Sort listing by file name or modified time"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var dir_path: String = str(get_param_value("path")).strip_edges()
	var recursive: bool = get_param_value("recursive")
	var filter_pat: String = str(get_param_value("filter")).strip_edges()
	var include_dirs: bool = get_param_value("include_dirs")
	var sort_mode: int = int(get_param_value("sort"))

	var tbl: GNTableData = _prepare_table(true)
	tbl.set_headers(PackedStringArray(["name", "path", "extension", "size", "is_dir", "modified"]))

	if dir_path.is_empty():
		return tbl

	var resolved := GNResourceLoader.resolve(dir_path, project_dir)
	if resolved.is_empty():
		resolved = dir_path

	var rows: Array = []  # Array of {cols: PackedStringArray, modified: int, name: String}
	_scan_dir(resolved, recursive, filter_pat, include_dirs, rows)

	if sort_mode == 1:
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.modified) < int(b.modified)
		)
	else:
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.name).naturalnocasecmp_to(str(b.name)) < 0
		)

	for row in rows:
		tbl.append_row(row.cols as PackedStringArray)
	return tbl


func _scan_dir(path: String, recursive: bool, filter_pat: String,
		include_dirs: bool, rows: Array) -> void:
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
				rows.append({
					"name": file_name,
					"modified": 0,
					"cols": PackedStringArray([
						file_name, full_path, "", "0", "true", "0"
					]),
				})
			if recursive:
				_scan_dir(full_path, true, filter_pat, include_dirs, rows)
		else:
			if _matches_filter(file_name, filter_pat):
				var ext: String = file_name.get_extension()
				var size_bytes: int = 0
				var modified: int = 0
				if FileAccess.file_exists(full_path):
					var f := FileAccess.open(full_path, FileAccess.READ)
					if f != null:
						size_bytes = f.get_length() as int
						f.close()
					modified = int(FileAccess.get_modified_time(full_path))
				rows.append({
					"name": file_name,
					"modified": modified,
					"cols": PackedStringArray([
						file_name, full_path, ext, str(size_bytes), "false", str(modified)
					]),
				})

		file_name = dir.get_next()
	dir.list_dir_end()


func _matches_filter(file_name: String, pattern: String) -> bool:
	if pattern == "*" or pattern.is_empty():
		return true
	return GNPattern.matches_any(file_name, pattern)
