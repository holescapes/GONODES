class_name GNTemplateStore
extends RefCounted
## Finds, checks, and describes prebuilt Player templates.
##
## A release editor ships with the player for its own OS under templates/.
## The first Build for another desktop target or the web downloads
## GONODESPlayer-<tag>-<platform>.zip from the GitHub release named in
## template_source.cfg. Android and iOS are not in that download.


const STAMP_NAME := "TEMPLATE_VERSION.txt"
const SOURCE_PATH := "res://addons/gonodes/template_source.cfg"

## Platforms a release editor can download.
const DOWNLOADABLE: PackedStringArray = [
	"windows_x86_64", "windows_arm64",
	"linux_x86_64", "linux_arm64",
	"macos", "web",
]

## Built on a machine with the vendor SDK, then copied into templates/.
const MANUAL: PackedStringArray = ["android", "ios"]


static func player_asset_name(tag: String, platform: String) -> String:
	return "GONODESPlayer-%s-%s.zip" % [tag, platform]


static func download_url(repository: String, tag: String, platform: String) -> String:
	if repository.is_empty() or tag.is_empty():
		return ""
	if not repository.contains("/") or repository.contains(".."):
		return ""
	return "https://github.com/%s/releases/download/%s/%s" % [
		repository, tag, player_asset_name(tag, platform)]


static func install_root() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://").path_join("templates")
	return OS.get_executable_path().get_base_dir().path_join("templates")


static func source_settings() -> Dictionary:
	var found := {
		"repository": "",
		"tag": "",
		"godot_version": "",
	}
	var cfg := ConfigFile.new()
	if cfg.load(SOURCE_PATH) != OK:
		return found
	found["repository"] = str(cfg.get_value("source", "repository", ""))
	found["tag"] = str(cfg.get_value("source", "tag", ""))
	found["godot_version"] = str(cfg.get_value("source", "godot_version", ""))
	return found


static func expected_gonodes_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


static func write_stamp(directory: String, godot_version: String, gonodes_version: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join(STAMP_NAME), FileAccess.WRITE)
	if file == null:
		return
	file.store_string("godot=%s\ngonodes=%s\n" % [godot_version, gonodes_version])
	file.close()


static func read_stamp(directory: String) -> Dictionary:
	var found := {"godot": "", "gonodes": ""}
	var path := directory.path_join(STAMP_NAME)
	if not FileAccess.file_exists(path):
		return found
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return found
	for line in file.get_as_text().split("\n"):
		var parts := line.split("=", true, 1)
		if parts.size() == 2 and found.has(parts[0]):
			found[parts[0]] = parts[1].strip_edges()
	file.close()
	return found


static func directory_has_player(directory: String) -> bool:
	if not DirAccess.dir_exists_absolute(directory):
		return false
	var listing := DirAccess.open(directory)
	if listing == null:
		return false
	listing.list_dir_begin()
	var name := listing.get_next()
	while name != "":
		if name != STAMP_NAME and not name.begins_with("."):
			listing.list_dir_end()
			return true
		name = listing.get_next()
	listing.list_dir_end()
	return false


## A folder with a player and no stamp is a local build. A stamp must match
## this editor's Godot version and GONODES version.
static func is_usable(directory: String) -> bool:
	if not directory_has_player(directory):
		return false
	var stamp := read_stamp(directory)
	if stamp["godot"].is_empty() and stamp["gonodes"].is_empty():
		return true
	var expected_godot := str(source_settings()["godot_version"])
	if not expected_godot.is_empty() and stamp["godot"] != expected_godot:
		return false
	var expected_app := expected_gonodes_version()
	if not expected_app.is_empty() and stamp["gonodes"] != expected_app:
		return false
	return true


static func manual_hint(platform: String) -> String:
	return ("Android and iOS players are not in the release download. "
		+ "Build that player with scripts/build_templates on a machine with the Android SDK or Xcode, "
		+ "then place it in templates/%s. See Help, Building.") % platform


static func can_download(platform: String) -> bool:
	if platform not in DOWNLOADABLE:
		return false
	var source := source_settings()
	return not download_url(str(source["repository"]), str(source["tag"]), platform).is_empty()


static func configured_download_url(platform: String) -> String:
	var source := source_settings()
	return download_url(str(source["repository"]), str(source["tag"]), platform)


static func hint_text(platform: String, platform_label: String) -> String:
	var directory := install_root().path_join(platform)
	if is_usable(directory):
		return ""
	if directory_has_player(directory):
		if can_download(platform):
			return "The %s player is from another version. Build will download the matching one." % platform_label
		return ("The %s player is from another GONODES or Godot version. "
			+ "Rebuild it with scripts/build_templates.") % platform_label
	if platform in MANUAL:
		return manual_hint(platform)
	if can_download(platform):
		return "The %s player downloads the first time you build." % platform_label
	return ("No template found for %s. "
		+ "Build it first: scripts/build_templates -Platforms %s") % [platform_label, platform]


static func extract_zip(zip_path: String, dest_dir: String) -> Error:
	var reader := ZIPReader.new()
	var open_err := reader.open(zip_path)
	if open_err != OK:
		return open_err
	DirAccess.make_dir_recursive_absolute(dest_dir)
	for rel in reader.get_files():
		var clean := str(rel).replace("\\", "/")
		if clean.is_empty() or clean.ends_with("/") or clean.contains(".."):
			continue
		var bytes: PackedByteArray = reader.read_file(clean)
		var out_path := dest_dir.path_join(clean)
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file == null:
			reader.close()
			return FileAccess.get_open_error()
		file.store_buffer(bytes)
		file.close()
		_mark_executable(out_path)
	reader.close()
	return OK


static func _mark_executable(path: String) -> void:
	if OS.get_name() == "Windows":
		return
	var base := path.get_file()
	var parent := path.get_base_dir().get_file()
	if base == "GONODESPlayer" or parent == "MacOS":
		OS.execute("chmod", ["+x", path], [], true)
