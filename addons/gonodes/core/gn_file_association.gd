class_name GNFileAssociation
extends RefCounted
## Points .gnpatch at this editor executable.
##
## A release editor calls [method claim_for_this_executable] on startup.
## If the association already names this executable, nothing is written.
## Opening a different editor rewrites the association to that copy.
## Running from the Godot editor (a debug build) does not claim the extension.


const PROG_ID := "GONODES.gnpatch"
const MIME := "application/x-gonodes-gnpatch"
const UTI := "com.gonodes.gnpatch"
const BUNDLE_ID := "com.gonodes.editor"


## Register this executable for .gnpatch when it is not already the handler.
static func claim_for_this_executable() -> void:
	# Play-in-editor uses the Godot binary. Do not bind .gnpatch to that.
	if OS.has_feature("editor") or OS.is_debug_build():
		return
	var exe := OS.get_executable_path()
	if exe.is_empty() or not FileAccess.file_exists(exe):
		return
	match OS.get_name():
		"Windows":
			_claim_windows(exe)
		"macOS":
			_claim_macos(exe)
		"Linux", "FreeBSD", "NetBSD", "OpenBSD":
			_claim_linux(exe)


## First .gnpatch path on the command line, or "" when the editor was opened plain.
static func patch_path_from_args() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	args.append_array(OS.get_cmdline_args())
	for raw in args:
		var arg := str(raw).strip_edges().trim_prefix("\"").trim_suffix("\"")
		if arg.is_empty() or arg.begins_with("-"):
			continue
		if arg.get_extension().to_lower() != "gnpatch":
			continue
		if FileAccess.file_exists(arg):
			return arg
	return ""


## Executable path stored in a Windows open-command or a quoted Exec line.
static func exe_from_open_command(text: String) -> String:
	var q1 := text.find("\"")
	if q1 < 0:
		return ""
	var q2 := text.find("\"", q1 + 1)
	if q2 < 0:
		return ""
	return text.substr(q1 + 1, q2 - q1 - 1)


static func same_executable(a: String, b: String) -> bool:
	var left := a.replace("\\", "/").simplify_path()
	var right := b.replace("\\", "/").simplify_path()
	if OS.get_name() == "Windows":
		return left.nocasecmp_to(right) == 0
	return left == right


## Value of the Windows shell open command for [param exe].
static func windows_open_command(exe: String) -> String:
	return "\"%s\" \"%%1\"" % exe


static func linux_desktop_text(exe: String) -> String:
	return """[Desktop Entry]
Type=Application
Name=GONODES Editor
Comment=Open GONODES patches
Exec=\"%s\" %%f
MimeType=%s;
Terminal=false
Categories=Graphics;
""" % [exe, MIME]


static func _claim_windows(exe: String) -> void:
	var registered := exe_from_open_command(_reg_query(
			"HKCU\\Software\\Classes\\%s\\shell\\open\\command" % PROG_ID))
	if same_executable(registered, exe):
		return
	var command := windows_open_command(exe)
	if _reg_set("HKCU\\Software\\Classes\\.gnpatch", PROG_ID) != OK:
		return
	_reg_set("HKCU\\Software\\Classes\\%s" % PROG_ID, "GONODES Patch")
	if _reg_set("HKCU\\Software\\Classes\\%s\\shell\\open\\command" % PROG_ID, command) == OK:
		GNLogger.info("Editor", "Associated .gnpatch with %s" % exe)


static func _claim_linux(exe: String) -> void:
	var home := OS.get_environment("HOME")
	if home.is_empty():
		return
	var desktop_path := home.path_join(".local/share/applications/gonodes-editor.desktop")
	var existing := FileAccess.get_file_as_string(desktop_path) if FileAccess.file_exists(desktop_path) else ""
	if same_executable(exe_from_open_command(existing), exe):
		return
	var mime_dir := home.path_join(".local/share/mime/packages")
	DirAccess.make_dir_recursive_absolute(desktop_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(mime_dir)
	var mime_xml := """<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="%s">
    <comment>GONODES Patch</comment>
    <glob pattern="*.gnpatch"/>
  </mime-type>
</mime-info>
""" % MIME
	if _write_text(mime_dir.path_join("gonodes-gnpatch.xml"), mime_xml) != OK:
		return
	if _write_text(desktop_path, linux_desktop_text(exe)) != OK:
		return
	_run("update-mime-database", PackedStringArray([home.path_join(".local/share/mime")]))
	_run("update-desktop-database", PackedStringArray([home.path_join(".local/share/applications")]))
	if _run("xdg-mime", PackedStringArray(["default", "gonodes-editor.desktop", MIME])) == OK:
		GNLogger.info("Editor", "Associated .gnpatch with %s" % exe)


static func _claim_macos(exe: String) -> void:
	var bundle := macos_bundle_path(exe)
	if bundle.is_empty():
		return
	var stamp_path := "user://gn_file_assoc.cfg"
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(stamp_path):
		cfg.load(stamp_path)
	var previous := str(cfg.get_value("assoc", "exe", ""))
	if same_executable(previous, exe):
		return
	var lsregister := "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
	if _run(lsregister, PackedStringArray(["-f", bundle])) != OK:
		return
	# Sets this bundle as the handler for the UTI declared in the editor Info.plist.
	var swift := "import CoreServices; LSSetDefaultRoleHandlerForContentType(\"%s\" as CFString, LSRolesMask.all, \"%s\" as CFString)" % [UTI, BUNDLE_ID]
	_run("/usr/bin/swift", PackedStringArray(["-e", swift]))
	cfg.set_value("assoc", "exe", exe)
	cfg.save(stamp_path)
	GNLogger.info("Editor", "Associated .gnpatch with %s" % bundle)


## .../Name.app/Contents/MacOS/Name → .../Name.app. Empty when this is not an app bundle.
static func macos_bundle_path(exe: String) -> String:
	var mac_os := exe.get_base_dir()
	if mac_os.get_file() != "MacOS":
		return ""
	var contents := mac_os.get_base_dir()
	if contents.get_file() != "Contents":
		return ""
	var bundle := contents.get_base_dir()
	if not bundle.get_file().ends_with(".app"):
		return ""
	return bundle


static func _reg_query(key: String) -> String:
	var output: Array = []
	var code := OS.execute("reg", PackedStringArray(["query", key, "/ve"]), output, true)
	if code != 0 or output.is_empty():
		return ""
	return str(output[0])


static func _reg_set(key: String, value: String) -> Error:
	var output: Array = []
	var code := OS.execute("reg", PackedStringArray([
		"add", key, "/ve", "/d", value, "/f"
	]), output, true)
	return OK if code == 0 else FAILED


static func _run(program: String, args: PackedStringArray) -> Error:
	var output: Array = []
	var code := OS.execute(program, args, output, true)
	return OK if code == 0 else FAILED


static func _write_text(path: String, text: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	return OK
