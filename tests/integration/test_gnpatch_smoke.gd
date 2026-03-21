extends Node
## Smoke test: loads every .gnpatch help file, deserializes the network,
## and verifies structural integrity.
##
## This catches broken patches, missing operator types, bad connections,
## and parameter deserialization errors across all 1,382 help patches.

var _patch_files: PackedStringArray = []


func before_all() -> void:
	_patch_files = _discover_patches()


# ═══════════════════════════════════════════════════════════════════════════════
# Discovery
# ═══════════════════════════════════════════════════════════════════════════════

func _discover_patches() -> PackedStringArray:
	var results: PackedStringArray = []
	# Core help patches
	_scan_patches("res://addons/gonodes/help/", results)
	# Extension help patches
	var addons_dir := DirAccess.open("res://addons/")
	if addons_dir != null:
		addons_dir.list_dir_begin()
		var folder := addons_dir.get_next()
		while folder != "":
			if addons_dir.current_is_dir() and folder.begins_with("gn_ext_"):
				var help_dir := "res://addons/".path_join(folder).path_join("help")
				if DirAccess.dir_exists_absolute(help_dir):
					_scan_patches(help_dir, results)
			folder = addons_dir.get_next()
		addons_dir.list_dir_end()
	return results


func _scan_patches(dir_path: String, results: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if dir.current_is_dir() and fname != "." and fname != "..":
			_scan_patches(dir_path.path_join(fname), results)
		elif fname.ends_with(".gnpatch"):
			results.append(dir_path.path_join(fname))
		fname = dir.get_next()
	dir.list_dir_end()


# ═══════════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Loads a .gnpatch file into the given network. Returns true on success.
func _load_patch_into(net: GNNetwork, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return false
	if not json.data is Dictionary:
		return false
	return net.from_dict(json.data)


# ═══════════════════════════════════════════════════════════════════════════════
# Tests
# ═══════════════════════════════════════════════════════════════════════════════

func test_patches_discovered() -> void:
	GNTestAssert.assert_gt(_patch_files.size(), 100,
		"Should discover 100+ .gnpatch files, found %d" % _patch_files.size())


func test_all_patches_load() -> void:
	var failures: PackedStringArray = PackedStringArray()
	for path in _patch_files:
		var net := GNNetwork.new()
		if not _load_patch_into(net, path):
			failures.append(path)

	if failures.size() > 0:
		var sample: String = ""
		var show_count: int = mini(failures.size(), 10)
		for i in range(show_count):
			sample += "\n    " + failures[i]
		if failures.size() > 10:
			sample += "\n    ... and %d more" % (failures.size() - 10)
		GNTestAssert.assert_eq(failures.size(), 0,
			"%d patches failed to load:%s" % [failures.size(), sample])
	else:
		GNTestAssert.assert_true(true,
			"All %d patches loaded successfully" % _patch_files.size())


func test_all_patches_have_nodes() -> void:
	var empty_patches: PackedStringArray = PackedStringArray()
	for path in _patch_files:
		var net := GNNetwork.new()
		if _load_patch_into(net, path) and net.nodes.size() == 0:
			empty_patches.append(path)

	GNTestAssert.assert_eq(empty_patches.size(), 0,
		"%d patches have zero nodes" % empty_patches.size())


func test_all_patches_have_valid_connections() -> void:
	var bad_patches: PackedStringArray = PackedStringArray()
	for path in _patch_files:
		var net := GNNetwork.new()
		if not _load_patch_into(net, path):
			continue
		for conn in net.connections:
			if not net.nodes.has(conn.from_id) or not net.nodes.has(conn.to_id):
				bad_patches.append(path)
				break

	GNTestAssert.assert_eq(bad_patches.size(), 0,
		"%d patches have dangling connections" % bad_patches.size())
