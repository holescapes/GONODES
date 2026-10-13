extends Node
## Player-template names, stamps, and the decision to download.


func test_template_store_asset_name() -> void:
	GNTestAssert.assert_eq(
		GNTemplateStore.player_asset_name("v0.1.0-beta", "linux_arm64"),
		"GONODESPlayer-v0.1.0-beta-linux_arm64.zip")


func test_template_store_download_url() -> void:
	GNTestAssert.assert_eq(GNTemplateStore.download_url("", "v1", "web"), "")
	GNTestAssert.assert_eq(GNTemplateStore.download_url("owner/gonodes", "", "web"), "")
	GNTestAssert.assert_eq(GNTemplateStore.download_url("../gonodes", "v1", "web"), "")
	GNTestAssert.assert_eq(
		GNTemplateStore.download_url("owner/gonodes", "v1", "web"),
		"https://github.com/owner/gonodes/releases/download/v1/GONODESPlayer-v1-web.zip")


func test_template_store_stamp() -> void:
	var directory := OS.get_cache_dir().path_join("gonodes_template_store_test")
	_remove_dir(directory)
	DirAccess.make_dir_recursive_absolute(directory)
	var marker := FileAccess.open(directory.path_join("GONODESPlayer"), FileAccess.WRITE)
	GNTestAssert.assert_not_null(marker)
	marker.store_string("player")
	marker.close()
	GNTestAssert.assert_true(GNTemplateStore.is_usable(directory))
	GNTemplateStore.write_stamp(directory, "9.9.9", "not-this-app")
	GNTestAssert.assert_false(GNTemplateStore.is_usable(directory))
	GNTemplateStore.write_stamp(
		directory,
		str(GNTemplateStore.source_settings()["godot_version"]),
		GNTemplateStore.expected_gonodes_version())
	GNTestAssert.assert_true(GNTemplateStore.is_usable(directory))
	_remove_dir(directory)


func test_template_store_android() -> void:
	GNTestAssert.assert_false(GNTemplateStore.can_download("android"))
	GNTestAssert.assert_false(GNTemplateStore.can_download("ios"))
	GNTestAssert.assert_contains(GNTemplateStore.manual_hint("android"), "Android SDK")
	GNTestAssert.assert_contains(GNTemplateStore.manual_hint("ios"), "Xcode")


func _remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var listing := DirAccess.open(path)
	if listing == null:
		return
	listing.list_dir_begin()
	var name := listing.get_next()
	while name != "":
		var child := path.path_join(name)
		if listing.current_is_dir():
			_remove_dir(child)
		else:
			DirAccess.remove_absolute(child)
		name = listing.get_next()
	listing.list_dir_end()
	DirAccess.remove_absolute(path)
