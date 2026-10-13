extends Node
## Unit tests for .gnpatch association path checks. Does not write the registry.


func test_open_command_names_the_executable() -> void:
	var exe := "C:/Editors/GONODESEditor.exe"
	var command := GNFileAssociation.windows_open_command(exe)
	GNTestAssert.assert_eq(GNFileAssociation.exe_from_open_command(command), exe, "exe from command")
	GNTestAssert.assert_true(command.contains("%1"), "command passes the patch path")


func test_a_different_editor_is_not_the_same_executable() -> void:
	var older := "C:/Old/GONODESEditor.exe"
	var newer := "C:/New/GONODESEditor.exe"
	var registered := "    (Default)    REG_SZ    " + GNFileAssociation.windows_open_command(older)
	var found := GNFileAssociation.exe_from_open_command(registered)
	GNTestAssert.assert_false(GNFileAssociation.same_executable(found, newer), "newer copy is a different target")
	GNTestAssert.assert_true(GNFileAssociation.same_executable(found, older.replace("/", "\\")), "slash style does not matter")


func test_linux_desktop_file_names_the_executable() -> void:
	var exe := "/home/me/GONODESEditor"
	var text := GNFileAssociation.linux_desktop_text(exe)
	GNTestAssert.assert_eq(GNFileAssociation.exe_from_open_command(text), exe, "desktop exec")
	GNTestAssert.assert_true(text.contains("application/x-gonodes-gnpatch"), "mime type")


func test_macos_bundle_path_from_executable() -> void:
	var exe := "/Applications/GONODESEditor.app/Contents/MacOS/GONODESEditor"
	GNTestAssert.assert_eq(
			GNFileAssociation.macos_bundle_path(exe),
			"/Applications/GONODESEditor.app",
			"bundle")
	GNTestAssert.assert_eq(GNFileAssociation.macos_bundle_path("/usr/bin/godot"), "", "not a bundle")
