extends Node
## Tests for extension disable prefs helpers in GNExtensionRegistry.


func test_extension_prefs_disabled_folder_skipped() -> void:
	var disabled := PackedStringArray(["gn_ext_ffmpeg", "gn_ext_ndi"])
	GNTestAssert.assert_true(
		GNExtensionRegistry.is_extension_folder_disabled("gn_ext_ffmpeg", disabled),
		"gn_ext_ffmpeg should be disabled")
	GNTestAssert.assert_false(
		GNExtensionRegistry.is_extension_folder_disabled("gn_ext_mapper", disabled),
		"gn_ext_mapper should not be disabled")


func test_extension_prefs_save_load_roundtrip() -> void:
	var backup_path := GNExtensionRegistry.EXTENSION_PREFS_PATH
	var had_backup := FileAccess.file_exists(backup_path)
	var backup_text := ""
	if had_backup:
		var rf := FileAccess.open(backup_path, FileAccess.READ)
		backup_text = rf.get_as_text()
		rf.close()

	var test_disabled := PackedStringArray(["gn_ext_test_only"])
	GNExtensionRegistry.save_disabled_extension_folders(test_disabled)
	var loaded := GNExtensionRegistry.load_disabled_extension_folders()
	GNTestAssert.assert_true(loaded.has("gn_ext_test_only"),
		"Saved disabled folder should round-trip through prefs file")

	if had_backup:
		var wf := FileAccess.open(backup_path, FileAccess.WRITE)
		wf.store_string(backup_text)
		wf.close()
	else:
		DirAccess.remove_absolute(backup_path)


func test_extension_unload_removes_registry_entries() -> void:
	var reg := GNExtensionRegistry.instance()
	const FOLDER := "gn_ext_example"
	const OP_NAME := "ExampleUnloadTestOP"
	const EXT_DIR := "res://addons/gn_ext_example"
	const ASSET_PATH := "res://addons/gn_ext_example/assets/example.gnasset"

	reg.register_operator(OP_NAME, "TOP", null, "unload test op", FOLDER, "Example", EXT_DIR)
	reg._loaded_extensions.append(FOLDER)

	var asset_entry := reg.register_operator("ExampleUnloadAsset", "TOP", GNCustomOperator,
		"unload test asset", "custom_asset", "Example", ASSET_PATH)
	asset_entry.is_custom_asset = true
	asset_entry.asset_read_only = true
	reg._loaded_assets.append(ASSET_PATH)

	GNTestAssert.assert_not_null(reg.get_entry(OP_NAME), "setup: operator registered")
	GNTestAssert.assert_true(reg.get_loaded_extensions().has(FOLDER), "setup: folder tracked")

	reg.unload_extension_folder(FOLDER)

	GNTestAssert.assert_null(reg.get_entry(OP_NAME), "operator should be unregistered")
	GNTestAssert.assert_null(reg.get_entry("ExampleUnloadAsset"), "extension asset should be unregistered")
	GNTestAssert.assert_false(reg.get_loaded_extensions().has(FOLDER),
		"folder should be removed from loaded extensions")
	GNTestAssert.assert_false(reg._loaded_assets.has(ASSET_PATH),
		"extension asset path should be dropped from loaded assets")
