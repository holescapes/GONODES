extends Node
## Smoke test: loads every .gnpatch help file, deserializes the network,
## and verifies structural integrity.
##
## This catches broken patches, missing operator types, bad connections,
## parameter deserialization errors, and graceful placeholder handling
## for operators from unavailable extensions.

var _patch_files: PackedStringArray = []
var _manual_patch_files: PackedStringArray = []


func before_all() -> void:
	_patch_files = _discover_patches()
	_manual_patch_files = _discover_manual_patches()


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


## Discovers .gnpatch files under tests/manual/ — these include comprehensive
## smoke tests (SmokeTest_ALL_TOPs, SmokeTest_ExtensionTOPs, etc.).
func _discover_manual_patches() -> PackedStringArray:
	var results: PackedStringArray = []
	_scan_patches("res://tests/manual/", results)
	return results


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


func test_manual_patches_discovered() -> void:
	GNTestAssert.assert_gt(_manual_patch_files.size(), 5,
		"Should discover 5+ manual .gnpatch files, found %d" % _manual_patch_files.size())


func test_manual_patches_load() -> void:
	var failures: PackedStringArray = PackedStringArray()
	for path in _manual_patch_files:
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
			"%d manual patches failed to load:%s" % [failures.size(), sample])
	else:
		GNTestAssert.assert_true(true,
			"All %d manual patches loaded successfully" % _manual_patch_files.size())


## Verifies that loading a patch with unknown operator types creates placeholder
## nodes with error badges instead of silently dropping them.
func test_missing_operator_creates_placeholder() -> void:
	var patch_data := {
		"nodes": {
			"real_node": {
				"type": "NoiseTOP",
				"position": [0.0, 0.0],
				"parameters": {}
			},
			"missing_node": {
				"type": "FakeOperatorTOP",
				"position": [200.0, 0.0],
				"parameters": {
					"speed": {"value": 1.5}
				}
			}
		},
		"connections": [
			{"from": "real_node", "from_port": 0, "to": "missing_node", "to_port": 0}
		]
	}

	var net := GNNetwork.new()
	var ok := net.from_dict(patch_data)
	GNTestAssert.assert_true(ok, "Patch with missing operator should still load")
	GNTestAssert.assert_eq(net.nodes.size(), 2,
		"Both real and placeholder nodes should exist")

	# The missing node should be a placeholder
	var missing: GNNode = net.nodes.get("missing_node", null)
	GNTestAssert.assert_not_null(missing, "Placeholder node should exist")
	if missing:
		GNTestAssert.assert_true(missing.is_placeholder(),
			"Missing operator should be flagged as placeholder")
		GNTestAssert.assert_true(missing.node_error.length() > 0,
			"Placeholder should have a non-empty error message")
		GNTestAssert.assert_eq(missing.node_type, "FakeOperatorTOP",
			"Placeholder should preserve the original type name")

	# Connection should still be present
	GNTestAssert.assert_eq(net.connections.size(), 1,
		"Connection to placeholder should be preserved")


## Verifies that re-serializing a patch with placeholder nodes preserves
## the original data (no round-trip data loss).
func test_placeholder_roundtrip() -> void:
	var original_data := {
		"nodes": {
			"noise1": {
				"type": "NoiseTOP",
				"position": [0.0, 0.0],
				"parameters": {
					"resolution": {"value": {"_type": "Vector2i", "x": 512, "y": 512}}
				}
			},
			"unknown1": {
				"type": "FutureTOP",
				"position": [300.0, 0.0],
				"parameters": {
					"custom_param": {"value": 42},
					"label": {"value": "test"}
				}
			}
		},
		"connections": [
			{"from": "noise1", "from_port": 0, "to": "unknown1", "to_port": 0}
		]
	}

	# Load → save → compare
	var net := GNNetwork.new()
	net.from_dict(original_data)
	var reserialized := net.to_dict()

	# The unknown operator's data should survive the round-trip
	GNTestAssert.assert_true(reserialized["nodes"].has("unknown1"),
		"Placeholder node should be preserved in to_dict()")
	var rt_node: Dictionary = reserialized["nodes"]["unknown1"]
	GNTestAssert.assert_eq(rt_node.get("type", ""), "FutureTOP",
		"Placeholder should preserve the original type name on re-save")
	GNTestAssert.assert_true(rt_node.has("parameters"),
		"Placeholder should preserve the original parameters on re-save")

	# Connection should survive
	GNTestAssert.assert_eq(reserialized["connections"].size(), 1,
		"Connections to placeholders should survive round-trip")


## Loads the extension TOPs smoke test — expects it to load successfully
## with some nodes as placeholders (extension operators without their
## native dependencies will be placeholders with error badges).
func test_extension_tops_smoke_patch() -> void:
	var path := "res://tests/manual/top/SmokeTest_ExtensionTOPs.gnpatch"
	var net := GNNetwork.new()
	var ok := _load_patch_into(net, path)
	GNTestAssert.assert_true(ok,
		"Extension TOPs smoke patch should load (with placeholders for missing extensions)")
	GNTestAssert.assert_gt(net.nodes.size(), 25,
		"Extension TOPs smoke patch should have 25+ nodes, found %d" % net.nodes.size())

	# Count placeholders — at minimum the core operators (NoiseTOP, NullTOP) should NOT be placeholders
	var placeholder_count := 0
	for nid in net.nodes:
		var node: GNNode = net.nodes[nid]
		if node.is_placeholder():
			placeholder_count += 1

	# NoiseTOP and NullTOP are core — they should always resolve
	var noise_node: GNNode = net.nodes.get("noise_src", null)
	if noise_node:
		GNTestAssert.assert_false(noise_node.is_placeholder(),
			"Core NoiseTOP should not be a placeholder")

	var null_node: GNNode = net.nodes.get("null_sink", null)
	if null_node:
		GNTestAssert.assert_false(null_node.is_placeholder(),
			"Core NullTOP should not be a placeholder")

	# Log how many extensions are available vs placeholders
	GNTestAssert.assert_true(true,
		"Extension TOPs patch: %d nodes total, %d placeholders (missing extensions)" % [
			net.nodes.size(), placeholder_count])


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
