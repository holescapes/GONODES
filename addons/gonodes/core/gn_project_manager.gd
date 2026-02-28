class_name GNProjectManager
extends RefCounted
## Manages the GONODES project folder structure.
##
## When a patch is saved as `/path/to/MyShow.gnpatch`, a sibling project
## folder `/path/to/MyShow/` is created (if it doesn't exist) with standard
## subfolders for user assets.  Operators store paths as `project://subfolder/file`
## which are resolved against this project folder at runtime.
##
## The project manager is the single source of truth for:
##   • Project directory path
##   • Subfolder structure and scanning
##   • Path conversion between absolute ↔ project-relative
##
## Lifecycle:
##   1. User saves a patch → set_from_patch_path() creates the project folder
##   2. User opens a patch → set_from_patch_path() picks up the existing folder
##   3. Untitled patches have no project folder (project_dir is empty)


## Emitted when the project directory changes (new patch, save-as, open).
signal project_changed(project_dir: String)


## Absolute path to the project folder, or "" if no project is active.
var project_dir: String = ""

## Absolute path to the current .gnpatch file, or "" if untitled.
var patch_path: String = ""


## Standard subfolders created in every project.
const SUBFOLDERS: PackedStringArray = PackedStringArray([
	"textures",
	"fonts",
	"video",
	"audio",
	"models",
	"shaders",
	"presets",
	"scripts",
	"data",
])


# ═══════════════════════════════════════════════════════════════════════════════
# Initialization
# ═══════════════════════════════════════════════════════════════════════════════

## Sets the project directory based on a .gnpatch file path.
## Creates the project folder and subfolders if they don't exist.
## [param p_patch_path] — absolute path to the .gnpatch file.
## Returns OK if the project folder is ready, or an error code.
func set_from_patch_path(p_patch_path: String) -> Error:
	if p_patch_path.is_empty():
		project_dir = ""
		patch_path = ""
		project_changed.emit("")
		return OK

	patch_path = p_patch_path
	# Project folder = same name as patch file, without extension, as a sibling directory.
	# e.g. /path/to/MyShow.gnpatch → /path/to/MyShow/
	var base_dir := p_patch_path.get_base_dir()
	var stem := p_patch_path.get_file().get_basename()
	project_dir = base_dir.path_join(stem)

	# Create the project folder and subfolders
	var err := _ensure_project_structure()
	if err != OK:
		GNLogger.error("ProjectManager",
			"Failed to create project folder: %s (error %d)" % [project_dir, err])
		return err

	GNLogger.info("ProjectManager",
		"Project folder ready: %s" % project_dir)
	project_changed.emit(project_dir)
	return OK


## Clears the project directory (e.g. when creating a new untitled patch).
func clear() -> void:
	project_dir = ""
	patch_path = ""
	project_changed.emit("")


# ═══════════════════════════════════════════════════════════════════════════════
# Path Helpers (delegate to GNResourceLoader statics)
# ═══════════════════════════════════════════════════════════════════════════════

## Resolves any path (project://, res://, absolute) to an absolute path.
func resolve_path(path: String) -> String:
	return GNResourceLoader.resolve(path, project_dir)


## Converts an absolute path to the best saveable form:
## - Inside project folder → project://relative/path
## - res:// → stays as-is
## - Outside project → stays absolute
func to_saveable(abs_path: String) -> String:
	return GNResourceLoader.to_saveable(abs_path, project_dir)


## Checks whether a resource exists at the given path (any tier).
func resource_exists(path: String) -> bool:
	return GNResourceLoader.exists(path, project_dir)


# ═══════════════════════════════════════════════════════════════════════════════
# Directory Scanning
# ═══════════════════════════════════════════════════════════════════════════════

## Scans a project subfolder for files matching the given extensions.
## [param subfolder]   — e.g. "textures", "fonts", "video".
## [param extensions]  — list of lowercase extensions without dots (e.g. ["png", "jpg"]).
## Returns an array of project:// paths.
func scan_subfolder(subfolder: String, extensions: Array[String]) -> Array[String]:
	if project_dir.is_empty():
		return []
	var scan_dir := project_dir.path_join(subfolder)
	if not DirAccess.dir_exists_absolute(scan_dir):
		return []
	var abs_paths := GNResourceLoader.scan_directory(scan_dir, extensions)
	# Convert to project:// paths
	var results: Array[String] = []
	for abs_path in abs_paths:
		results.append(GNResourceLoader.to_project_relative(abs_path, project_dir))
	return results


## Scans ALL project subfolders for files matching the given extensions.
## Returns merged project:// paths sorted alphabetically.
func scan_all_subfolders(extensions: Array[String]) -> Array[String]:
	var results: Array[String] = []
	for subfolder in SUBFOLDERS:
		results.append_array(scan_subfolder(subfolder, extensions))
	results.sort()
	return results


## Returns the absolute path to a project subfolder, creating it if needed.
## Returns "" if no project is active.
func get_subfolder_path(subfolder: String) -> String:
	if project_dir.is_empty():
		return ""
	var path := project_dir.path_join(subfolder)
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
	return path


## Returns true if a project folder is active (patch has been saved).
func has_project() -> bool:
	return not project_dir.is_empty()


# ═══════════════════════════════════════════════════════════════════════════════
# Internals
# ═══════════════════════════════════════════════════════════════════════════════

## Creates the project directory and all standard subfolders.
func _ensure_project_structure() -> Error:
	if project_dir.is_empty():
		return ERR_INVALID_PARAMETER

	if not DirAccess.dir_exists_absolute(project_dir):
		var err := DirAccess.make_dir_recursive_absolute(project_dir)
		if err != OK:
			return err

	for subfolder in SUBFOLDERS:
		var sub_path := project_dir.path_join(subfolder)
		if not DirAccess.dir_exists_absolute(sub_path):
			var err := DirAccess.make_dir_recursive_absolute(sub_path)
			if err != OK:
				GNLogger.warn("ProjectManager",
					"Failed to create subfolder: %s" % sub_path)
				# Non-fatal — continue creating other subfolders
	return OK
