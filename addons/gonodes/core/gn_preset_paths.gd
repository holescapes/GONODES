class_name GNPresetPaths
extends RefCounted
## Unified preset path management for all GONODES preset systems.
##
## Three categories of presets:
##   • **params** — Parameter value snapshots (JSON).
##   • **code**   — Code editor presets (GDScript / GLSL / ISF).
##   • **assets** — Custom operator definitions (.gnasset).
##
## Directory layout:
##   Factory (read-only):  res://addons/gonodes/presets/<category>/
##   Extensions:           res://addons/gn_ext_*/presets/<category>/
##   User (read-write):    user://gonodes/presets/<category>/


# ═══════════════════════════════════════════════════════════════════════════════
# Constants
# ═══════════════════════════════════════════════════════════════════════════════

## Canonical user root — all user-writable preset data lives here.
const USER_ROOT := "user://gonodes/presets/"

## Factory root — ships with the addon (read-only).
const FACTORY_ROOT := "res://addons/gonodes/presets/"

## Category sub-folders under both factory and user roots.
const CATEGORY_PARAMS := "params"
const CATEGORY_CODE := "code"
const CATEGORY_ASSETS := "assets"

## Whether dirs have already been created this session.
static var _dirs_created_this_session: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# Public — Directory Accessors
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the user-writable directory for parameter presets.
## Creates it if it doesn't exist.
static func user_params_dir() -> String:
	_ensure_user_dirs()
	return USER_ROOT + CATEGORY_PARAMS + "/"


## Returns the user-writable directory for code presets.
## Creates it if it doesn't exist.
static func user_code_dir() -> String:
	_ensure_user_dirs()
	return USER_ROOT + CATEGORY_CODE + "/"


## Returns the user-writable directory for custom operator assets.
## Creates it if it doesn't exist.
static func user_assets_dir() -> String:
	_ensure_user_dirs()
	return USER_ROOT + CATEGORY_ASSETS + "/"


## Returns the factory preset root.
static func factory_root() -> String:
	return FACTORY_ROOT


## Returns the factory directory for parameter presets.
static func factory_params_dir() -> String:
	return FACTORY_ROOT + CATEGORY_PARAMS + "/"


## Returns the factory directory for code presets.
static func factory_code_dir() -> String:
	return FACTORY_ROOT + CATEGORY_CODE + "/"


# ═══════════════════════════════════════════════════════════════════════════════
# Public — Scanning
# ═══════════════════════════════════════════════════════════════════════════════

## Returns all parameter preset directories to scan for [param operator_type].
## Order: factory → extensions → user.
static func get_param_preset_dirs(operator_type: String) -> PackedStringArray:
	_ensure_user_dirs()
	var dirs := PackedStringArray()
	# Factory
	dirs.append(FACTORY_ROOT + CATEGORY_PARAMS + "/" + operator_type)
	# User
	dirs.append(USER_ROOT + CATEGORY_PARAMS + "/" + operator_type)
	return dirs


## Returns all code preset directories to scan for [param family_folder].
## Order: factory → extensions → user.
static func get_code_preset_dirs(family_folder: String) -> PackedStringArray:
	_ensure_user_dirs()
	var dirs := PackedStringArray()
	# Core factory
	dirs.append(FACTORY_ROOT + family_folder)
	# Extension presets
	var addons_dir := DirAccess.open("res://addons")
	if addons_dir != null:
		addons_dir.list_dir_begin()
		var folder_name := addons_dir.get_next()
		while folder_name != "":
			if addons_dir.current_is_dir() and folder_name.begins_with("gn_ext_"):
				dirs.append("res://addons/%s/presets/%s" % [folder_name, family_folder])
			folder_name = addons_dir.get_next()
		addons_dir.list_dir_end()
	# User
	dirs.append(USER_ROOT + CATEGORY_CODE + "/" + family_folder)
	return dirs


## Returns all directories to scan for custom operator assets.
## Order: factory → project-local → user.
static func get_asset_dirs() -> PackedStringArray:
	_ensure_user_dirs()
	var dirs := PackedStringArray()
	dirs.append("res://addons/gonodes/assets/")
	dirs.append("res://custom_operators/")
	dirs.append(USER_ROOT + CATEGORY_ASSETS + "/")
	return dirs


## Returns the user-writable save path for a parameter preset.
static func get_param_preset_save_dir(operator_type: String) -> String:
	_ensure_user_dirs()
	return USER_ROOT + CATEGORY_PARAMS + "/" + operator_type


## Returns the user-writable save path for a code preset.
static func get_code_preset_save_dir(family_folder: String) -> String:
	_ensure_user_dirs()
	return USER_ROOT + CATEGORY_CODE + "/" + family_folder


## Returns the user-writable save path for a custom operator asset.
static func get_asset_save_dir() -> String:
	_ensure_user_dirs()
	return USER_ROOT + CATEGORY_ASSETS + "/"


# ═══════════════════════════════════════════════════════════════════════════════
# Directory Initialization
# ═══════════════════════════════════════════════════════════════════════════════

## Ensures user directories exist.
## Called automatically on first directory access each session.
static func _ensure_user_dirs() -> void:
	if _dirs_created_this_session:
		return
	_dirs_created_this_session = true

	for subdir in [CATEGORY_PARAMS, CATEGORY_CODE, CATEGORY_ASSETS]:
		var path: String = USER_ROOT + subdir
		if not DirAccess.dir_exists_absolute(path):
			DirAccess.make_dir_recursive_absolute(path)
