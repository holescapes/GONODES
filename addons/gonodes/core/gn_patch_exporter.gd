class_name GNPatchExporter
extends RefCounted
## Exports a GONODES patch as a standalone application.
##
## Two modes:
##   1. **Quick Build** — copies a pre-built GONODESPlayer binary + patch +
##      project assets + config.json to an output folder.  Instant, no Godot
##      export templates needed.  Desktop only (Win/Mac/Linux).
##   2. **Full Export** — (future) generates a minimal Godot project and invokes
##      `godot --export-release` to produce a single binary or web/mobile package.
##
## Usage:
##   var exporter := GNPatchExporter.new()
##   exporter.patch_path = "/path/to/MyShow.gnpatch"
##   exporter.output_dir = "/path/to/build/"
##   var err := exporter.quick_build()


## Emitted with progress messages during export.
signal progress(message: String)

## Emitted when the export finishes (success or failure).
signal completed(success: bool, message: String)


## Absolute path to the .gnpatch file to export.
var patch_path: String = ""

## Absolute path to the output directory.  Will be created if it doesn't exist.
var output_dir: String = ""


# ═══════════════════════════════════════════════════════════════════════════════
# Quick Build
# ═══════════════════════════════════════════════════════════════════════════════

## Performs a Quick Build: copies Player binary + patch + assets + config.
## Returns OK on success, or an error code.
func quick_build() -> Error:
	if patch_path.is_empty():
		_fail("No patch file specified.")
		return ERR_INVALID_PARAMETER
	if output_dir.is_empty():
		_fail("No output directory specified.")
		return ERR_INVALID_PARAMETER
	if not FileAccess.file_exists(patch_path):
		_fail("Patch file not found: %s" % patch_path)
		return ERR_FILE_NOT_FOUND

	# 1. Ensure output directory exists
	progress.emit("Creating output directory...")
	var err := _ensure_dir(output_dir)
	if err != OK:
		_fail("Cannot create output directory: %s (error %d)" % [output_dir, err])
		return err

	# 2. Locate the Player binary
	progress.emit("Locating Player binary...")
	var player_path := _find_player_binary()
	if player_path.is_empty():
		_fail("GONODESPlayer binary not found.\n\n"
			+ "Expected next to the editor executable or in the project root.\n"
			+ "Build the Player using Godot's export system first.")
		return ERR_FILE_NOT_FOUND

	# 3. Copy Player binary to output
	progress.emit("Copying Player binary...")
	var player_dest := output_dir.path_join(player_path.get_file())
	err = _copy_file(player_path, player_dest)
	if err != OK:
		_fail("Failed to copy Player binary (error %d)" % err)
		return err

	# 4. Copy the .pck file if it exists (Godot export produces exe + pck pair)
	var pck_source := player_path.get_basename() + ".pck"
	if FileAccess.file_exists(pck_source):
		progress.emit("Copying Player data pack...")
		var pck_dest := output_dir.path_join(pck_source.get_file())
		err = _copy_file(pck_source, pck_dest)
		if err != OK:
			_fail("Failed to copy .pck file (error %d)" % err)
			return err

	# 5. Copy the .gnpatch file
	progress.emit("Copying patch file...")
	var patch_filename := patch_path.get_file()
	err = _copy_file(patch_path, output_dir.path_join(patch_filename))
	if err != OK:
		_fail("Failed to copy patch file (error %d)" % err)
		return err

	# 6. Copy the project folder (assets) if it exists
	var project_mgr := GNProjectManager.new()
	project_mgr.set_from_patch_path(patch_path)
	if project_mgr.has_project():
		progress.emit("Copying project assets...")
		var assets_source := project_mgr.project_dir
		var assets_dest := output_dir.path_join(assets_source.get_file())
		err = _copy_dir_recursive(assets_source, assets_dest)
		if err != OK:
			_fail("Failed to copy project assets (error %d)" % err)
			return err

	# 7. Write config.json
	progress.emit("Writing config.json...")
	err = _write_config(output_dir.path_join("config.json"), patch_filename)
	if err != OK:
		_fail("Failed to write config.json (error %d)" % err)
		return err

	var msg := "Quick Build complete: %s" % output_dir
	progress.emit(msg)
	completed.emit(true, msg)
	return OK


# ═══════════════════════════════════════════════════════════════════════════════
# Player Binary Discovery
# ═══════════════════════════════════════════════════════════════════════════════

## Searches for the GONODESPlayer binary in standard locations.
## Returns the absolute path to the binary, or "" if not found.
func _find_player_binary() -> String:
	var exe_name := _get_player_exe_name()
	var search_dirs: PackedStringArray = []

	# 1. Next to the current executable (standalone editor)
	var exe_dir := OS.get_executable_path().get_base_dir()
	search_dirs.append(exe_dir)

	# 2. Project root (running from Godot editor)
	var project_root := ProjectSettings.globalize_path("res://")
	search_dirs.append(project_root)

	# 3. templates/<platform>/ subfolder (produced by build_templates.ps1)
	var templates_subdir := _get_templates_platform_dir()
	if not templates_subdir.is_empty():
		search_dirs.append(project_root.path_join("templates").path_join(templates_subdir))
		search_dirs.append(exe_dir.path_join("templates").path_join(templates_subdir))

	# 4. Explicit "player" or "build" subdirectories
	search_dirs.append(project_root.path_join("player"))
	search_dirs.append(project_root.path_join("build"))
	search_dirs.append(exe_dir.path_join("player"))

	for dir in search_dirs:
		var candidate := dir.path_join(exe_name)
		if FileAccess.file_exists(candidate):
			return candidate

	return ""


## Returns the templates/ subfolder name for the current OS + architecture.
func _get_templates_platform_dir() -> String:
	var os_name := OS.get_name()
	match os_name:
		"Windows":
			var arch := Engine.get_architecture_name()  # e.g. "x86_64", "arm64"
			if arch.contains("arm") or arch.contains("aarch"):
				return "windows_arm64"
			return "windows_x86_64"
		"Linux", "FreeBSD":
			var arch := Engine.get_architecture_name()
			if arch.contains("arm") or arch.contains("aarch"):
				return "linux_arm64"
			return "linux_x86_64"
		"macOS":
			return "macos"
		_:
			return ""


## Returns the expected Player binary filename for the current OS.
func _get_player_exe_name() -> String:
	match OS.get_name():
		"Windows":
			return "GONODESPlayer.exe"
		"macOS":
			return "GONODESPlayer.app"
		"Linux":
			return "GONODESPlayer"
		_:
			return "GONODESPlayer"


# ═══════════════════════════════════════════════════════════════════════════════
# Config File
# ═══════════════════════════════════════════════════════════════════════════════

## Writes the config.json file for the Player.
func _write_config(config_path: String, patch_filename: String) -> Error:
	var config := {
		"patch": patch_filename,
	}

	var json_string := JSON.stringify(config, "\t")
	var file := FileAccess.open(config_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json_string)
	file.close()
	return OK


# ═══════════════════════════════════════════════════════════════════════════════
# File System Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Ensures a directory exists, creating it recursively if needed.
func _ensure_dir(path: String) -> Error:
	if DirAccess.dir_exists_absolute(path):
		return OK
	return DirAccess.make_dir_recursive_absolute(path)


## Copies a single file from src to dst.
func _copy_file(src: String, dst: String) -> Error:
	# Ensure destination directory exists
	var dst_dir := dst.get_base_dir()
	if not DirAccess.dir_exists_absolute(dst_dir):
		var err := DirAccess.make_dir_recursive_absolute(dst_dir)
		if err != OK:
			return err

	var dir := DirAccess.open(src.get_base_dir())
	if dir == null:
		return DirAccess.get_open_error()
	return dir.copy(src, dst)


## Recursively copies a directory tree from src_dir to dst_dir.
func _copy_dir_recursive(src_dir: String, dst_dir: String) -> Error:
	var err := _ensure_dir(dst_dir)
	if err != OK:
		return err

	var dir := DirAccess.open(src_dir)
	if dir == null:
		return DirAccess.get_open_error()

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var src_path := src_dir.path_join(entry)
		var dst_path := dst_dir.path_join(entry)

		if dir.current_is_dir():
			# Skip hidden directories (e.g. .git, .godot)
			if not entry.begins_with("."):
				err = _copy_dir_recursive(src_path, dst_path)
				if err != OK:
					dir.list_dir_end()
					return err
		else:
			err = _copy_file(src_path, dst_path)
			if err != OK:
				dir.list_dir_end()
				return err

		entry = dir.get_next()
	dir.list_dir_end()
	return OK


## Reports a failure via signal and push_error.
func _fail(message: String) -> void:
	push_error("[GNPatchExporter] %s" % message)
	completed.emit(false, message)
