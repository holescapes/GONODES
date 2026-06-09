class_name GNPatchExporter
extends RefCounted
## Exports a GONODES patch as a standalone application.
##
## Quick Build copies a pre-built Player binary/package + patch + project
## assets + config.json to an output folder.  Supports eight platform targets:
##
##   • **windows_x86_64 / windows_arm64** — .exe + .pck
##   • **linux_x86_64 / linux_arm64**     — binary + .pck
##   • **macos**                          — .app bundle
##   • **android**                        — .apk + config.json + patch
##   • **ios**                            — .ipa + config.json + patch (requires re-sign)
##   • **web**                            — .html/.wasm/.pck + config.json + embedded patch
##
## The renderer is chosen independently by the user and recorded in config.json
## so the Player can select the correct rendering backend on launch.
##
## Pre-built templates live in `templates/<platform>/` next to the editor
## binary or in the project root.  Built via `scripts/build_templates.ps1`.


## Emitted with progress messages during export.
signal progress(message: String)

## Emitted when the export finishes (success or failure).
signal completed(success: bool, message: String)


## Absolute path to the .gnpatch file to export.
var patch_path: String = ""

## Absolute path to the output directory.  Will be created if it doesn't exist.
var output_dir: String = ""

## Target platform ID — one of the eight concrete IDs:
##   windows_x86_64, windows_arm64, linux_x86_64, linux_arm64,
##   macos, android, ios, web
var target_platform: String = "windows_x86_64"

## Target renderer chosen by the user:
##   forward_plus, mobile, gl_compatibility
## Written into config.json so the Player selects the right backend.
var target_renderer: String = "forward_plus"

## Desktop platform IDs (produce exe/binary + .pck).
const _DESKTOP_PLATFORMS := ["windows_x86_64", "windows_arm64", "linux_x86_64", "linux_arm64", "macos"]

## Mobile platform IDs (produce .apk / .ipa bundles).
const _MOBILE_PLATFORMS := ["android", "ios"]

# ═══════════════════════════════════════════════════════════════════════════════
# Quick Build — Public Entry Point
# ═══════════════════════════════════════════════════════════════════════════════

## Performs a Quick Build for the selected target_platform.
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

	# Build into a named subfolder: PatchName_Platform_Renderer
	var patch_name := patch_path.get_file().get_basename()
	var subfolder := "%s_%s_%s" % [patch_name, target_platform, target_renderer]
	output_dir = output_dir.path_join(subfolder)

	if target_platform in _DESKTOP_PLATFORMS:
		return _quick_build_desktop()
	elif target_platform in _MOBILE_PLATFORMS:
		return _quick_build_mobile()
	elif target_platform == "web":
		return _quick_build_web()
	else:
		_fail("Unknown target platform: %s" % target_platform)
		return ERR_INVALID_PARAMETER


# ═══════════════════════════════════════════════════════════════════════════════
# Desktop Quick Build
# ═══════════════════════════════════════════════════════════════════════════════

func _quick_build_desktop() -> Error:
	# 1. Ensure output directory exists
	progress.emit("Creating output directory...")
	var err := _ensure_dir(output_dir)
	if err != OK:
		_fail("Cannot create output directory: %s (error %d)" % [output_dir, err])
		return err

	# 2. Locate the Player template directory for this specific platform
	progress.emit("Locating %s Player template..." % target_platform)
	var template_dir := _find_template_dir(target_platform)

	if template_dir.is_empty():
		_fail("Player template not found for '%s'.\n\n"
			+ "Expected at templates/%s/ next to the editor or project root.\n"
			+ "Build it with: scripts/build_templates -Platforms %s" % [
			target_platform, target_platform, target_platform])
		return ERR_FILE_NOT_FOUND

	# 3. Copy all template files to output
	progress.emit("Copying Player files...")
	err = _copy_dir_recursive(template_dir, output_dir)
	if err != OK:
		_fail("Failed to copy Player template (error %d)" % err)
		return err

	# 4. Copy patch + assets + config
	err = _copy_patch_and_config()
	if err != OK:
		return err

	_succeed("%s build complete: %s" % [target_platform, output_dir])
	return OK


# ═══════════════════════════════════════════════════════════════════════════════
# Web Quick Build
# ═══════════════════════════════════════════════════════════════════════════════

func _quick_build_web() -> Error:
	progress.emit("Creating output directory...")
	var err := _ensure_dir(output_dir)
	if err != OK:
		_fail("Cannot create output directory: %s (error %d)" % [output_dir, err])
		return err

	# Find the web template directory
	progress.emit("Locating Web Player template...")
	var web_dir := _find_template_dir("web")
	if web_dir.is_empty():
		_fail("Web Player template not found.\n\n"
			+ "Expected at templates/web/ next to the editor or project root.\n"
			+ "Build it with: scripts/build_templates -Platforms web")
		return ERR_FILE_NOT_FOUND

	# Copy all web template files (.html, .wasm, .pck, .js, .png, service worker, etc.)
	progress.emit("Copying Web Player files...")
	err = _copy_dir_recursive(web_dir, output_dir)
	if err != OK:
		_fail("Failed to copy Web Player template (error %d)" % err)
		return err

	# Copy patch + assets + config (config uses patch_url for web)
	err = _copy_patch_and_config()
	if err != OK:
		return err

	_succeed("Web build complete: %s\n\nServe with any HTTP server. COOP/COEP headers required for threading." % output_dir)
	return OK


# ═══════════════════════════════════════════════════════════════════════════════
# Mobile Quick Build (Android / iOS)
# ═══════════════════════════════════════════════════════════════════════════════

func _quick_build_mobile() -> Error:
	var platform_label := target_platform.capitalize()
	progress.emit("Creating output directory...")
	var err := _ensure_dir(output_dir)
	if err != OK:
		_fail("Cannot create output directory: %s (error %d)" % [output_dir, err])
		return err

	# Find the mobile template directory
	progress.emit("Locating %s Player template..." % platform_label)
	var mobile_dir := _find_template_dir(target_platform)
	if mobile_dir.is_empty():
		_fail("%s Player template not found.\n\n"
			% platform_label
			+ "Expected at templates/%s/ next to the editor or project root.\n" % target_platform
			+ "Build it with: scripts/build_templates -Platforms %s" % target_platform)
		return ERR_FILE_NOT_FOUND

	# Copy all mobile template files (.apk/.ipa + any supporting files)
	progress.emit("Copying %s Player package..." % platform_label)
	err = _copy_dir_recursive(mobile_dir, output_dir)
	if err != OK:
		_fail("Failed to copy %s Player template (error %d)" % [platform_label, err])
		return err

	# Copy patch + assets + config
	err = _copy_patch_and_config()
	if err != OK:
		return err

	var extra_note: String = ""
	if target_platform == "ios":
		extra_note = "\n\nNote: The .ipa must be re-signed with your Apple developer certificate before deploying."
	elif target_platform == "android":
		extra_note = "\n\nInstall via: adb install -r <apk path>"

	_succeed("%s build complete: %s%s" % [platform_label, output_dir, extra_note])
	return OK


# ═══════════════════════════════════════════════════════════════════════════════
# Shared: Copy Patch + Assets + Config
# ═══════════════════════════════════════════════════════════════════════════════

## Copies .gnpatch, project assets, and writes config.json to output_dir.
## Used by all platform build paths.
func _copy_patch_and_config() -> Error:
	# Copy the .gnpatch file
	progress.emit("Copying patch file...")
	var patch_filename := patch_path.get_file()
	var err := _copy_file(patch_path, output_dir.path_join(patch_filename))
	if err != OK:
		_fail("Failed to copy patch file (error %d)" % err)
		return err

	# Copy the project folder (assets) if it exists and has files
	var project_mgr := GNProjectManager.new()
	project_mgr.set_from_patch_path(patch_path)
	if project_mgr.has_project() and DirAccess.dir_exists_absolute(project_mgr.project_dir):
		if _dir_has_files(project_mgr.project_dir):
			progress.emit("Copying project assets...")
			var assets_source := project_mgr.project_dir
			var assets_dest := output_dir.path_join(assets_source.get_file())
			err = _copy_dir_recursive(assets_source, assets_dest)
			if err != OK:
				_fail("Failed to copy project assets (error %d)" % err)
				return err

	# Write config.json
	progress.emit("Writing config.json...")
	err = _write_config(output_dir.path_join("config.json"), patch_filename)
	if err != OK:
		_fail("Failed to write config.json (error %d)" % err)
		return err

	return OK


# ═══════════════════════════════════════════════════════════════════════════════
# Template & Binary Discovery
# ═══════════════════════════════════════════════════════════════════════════════

## Searches for a platform template directory in standard locations.
## Returns the absolute path to the directory, or "" if not found.
func _find_template_dir(platform: String) -> String:
	var search_roots: PackedStringArray = []
	var exe_dir := OS.get_executable_path().get_base_dir()
	var project_root := ProjectSettings.globalize_path("res://")
	search_roots.append(project_root)
	search_roots.append(exe_dir)

	for root in search_roots:
		var candidate := root.path_join("templates").path_join(platform)
		if DirAccess.dir_exists_absolute(candidate):
			# Verify it has at least one file (not an empty placeholder)
			var d := DirAccess.open(candidate)
			if d != null:
				d.list_dir_begin()
				var first := d.get_next()
				d.list_dir_end()
				if not first.is_empty():
					return candidate
	return ""


# ═══════════════════════════════════════════════════════════════════════════════
# Config File
# ═══════════════════════════════════════════════════════════════════════════════

## Writes the config.json file for the Player.
## For web builds, uses "patch_url" key so the Player fetches via HTTP.
## For desktop/mobile, uses "patch" key for local file path.
## Includes all available options with defaults so users can see and tweak them.
func _write_config(config_path: String, patch_filename: String) -> Error:
	var config: Dictionary = {}

	# ── Patch path ──────────────────────────────────────────────────────
	if target_platform == "web":
		config["patch_url"] = patch_filename
	else:
		config["patch"] = patch_filename

	# ── Renderer ────────────────────────────────────────────────────────
	config["renderer"] = target_renderer

	# ── Runtime settings ────────────────────────────────────────────────
	config["settings"] = {
		"log_level": GNSettings.get_value("log_level", 1),
		"log_to_file": GNSettings.get_value("log_to_file", false),
		"parallel_cook_enabled": GNSettings.get_value("parallel_cook_enabled", false),
		"max_cooks_per_frame": GNSettings.get_value("max_cooks_per_frame", 0),
	}

	var json_string := JSON.stringify(config, "\t")
	var file := FileAccess.open(config_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json_string)
	file.close()

	# Write companion documentation alongside config.json.
	var doc_path := config_path.get_base_dir().path_join("CONFIG_OPTIONS.txt")
	_write_config_docs(doc_path)

	return OK


## Writes CONFIG_OPTIONS.txt alongside config.json documenting all fields.
func _write_config_docs(doc_path: String) -> void:
	var doc := """GONODES Player — config.json Reference
=======================================

Place config.json next to the Player executable.
All fields are optional except "patch" (or "patch_url" for web).
CLI arguments override config.json values.

┌─────────────────────────────────────────────────────────────────────┐
│  TOP-LEVEL FIELDS                                                   │
├──────────────────┬──────────────┬────────────────────────────────────┤
│ Field            │ Type         │ Description                        │
├──────────────────┼──────────────┼────────────────────────────────────┤
│ patch            │ string       │ Path to .gnpatch file (relative    │
│                  │              │ to exe directory or absolute).     │
│                  │              │ Required for desktop/mobile.       │
├──────────────────┼──────────────┼────────────────────────────────────┤
│ patch_url        │ string       │ URL or relative path for web       │
│                  │              │ builds. Player fetches via HTTP.   │
│                  │              │ Required for web, ignored on       │
│                  │              │ desktop.                           │
├──────────────────┼──────────────┼────────────────────────────────────┤
│ renderer         │ string       │ Rendering backend. If the running  │
│                  │              │ renderer doesn't match, the Player │
│                  │              │ re-launches with the correct one.  │
│                  │              │                                    │
│                  │              │ Values:                            │
│                  │              │   "forward_plus"      (Vulkan/D3D) │
│                  │              │   "mobile"            (Vulkan mob) │
│                  │              │   "gl_compatibility"  (OpenGL/Web) │
│                  │              │                                    │
│                  │              │ Default: forward_plus              │
└──────────────────┴──────────────┴────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  SETTINGS (nested under "settings")                                 │
├──────────────────────┬─────────┬─────────┬──────────────────────────┤
│ Field                │ Type    │ Default │ Description              │
├──────────────────────┼─────────┼─────────┼──────────────────────────┤
│ log_level            │ int     │ 1       │ 0=Debug 1=Info 2=Warn    │
│                      │         │         │ 3=Error                  │
├──────────────────────┼─────────┼─────────┼──────────────────────────┤
│ log_to_file          │ bool    │ false   │ Write log to             │
│                      │         │         │ gonodes.log next to exe  │
├──────────────────────┼─────────┼─────────┼──────────────────────────┤
│ parallel_cook_enabled│ bool    │ false   │ Cook independent nodes   │
│                      │         │         │ on worker threads.       │
│                      │         │         │ Experimental.            │
├──────────────────────┼─────────┼─────────┼──────────────────────────┤
│ max_cooks_per_frame  │ int     │ 0       │ Throttle node cooks per  │
│                      │         │         │ frame. 0 = unlimited.    │
└──────────────────────┴─────────┴─────────┴──────────────────────────┘

CLI OVERRIDES (take priority over config.json):

  --patch <path>              Override patch path
  --rendering-method <name>   Override renderer (forward_plus|mobile|gl_compatibility)
  --log-level <0-3>           Override log level
  --log-file [path]           Enable file logging (default: gonodes.log)
  --parallel-cook             Enable parallel cooking
  --max-cooks <N>             Override max cooks per frame

EXAMPLE config.json:

{
    "patch": "MyShow.gnpatch",
    "renderer": "forward_plus",
    "settings": {
        "log_level": 1,
        "log_to_file": false,
        "parallel_cook_enabled": false,
        "max_cooks_per_frame": 0
    }
}

NOTE: VSync and window settings are controlled per-WindowOUT in the
patch, not in config.json. A single patch can have multiple WindowOUTs
with independent VSync settings.
"""
	var file := FileAccess.open(doc_path, FileAccess.WRITE)
	if file != null:
		file.store_string(doc)
		file.close()


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


## Returns true if a directory contains at least one non-hidden file or subfolder.
func _dir_has_files(path: String) -> bool:
	var d := DirAccess.open(path)
	if d == null:
		return false
	d.list_dir_begin()
	var entry := d.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			d.list_dir_end()
			return true
		entry = d.get_next()
	d.list_dir_end()
	return false


## Reports a failure via GNLogger and emits the completed signal with failure state.
func _fail(message: String) -> void:
	GNLogger.error("PatchExporter", message)
	completed.emit(false, message)


## Reports success via signal.
func _succeed(message: String) -> void:
	progress.emit(message)
	completed.emit(true, message)
