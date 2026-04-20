class_name GNBlackmagicHelper
## Shared utilities for Blackmagic DeckLink operators.
##
## Caches device enumeration results so multiple operators avoid repeated
## hardware probing.  Call rescan() to force a fresh enumeration.

# ── Cached state (shared across all operators) ───────────────────────────────

static var _devices: Array = []   # Array[Dictionary] — device info dicts
static var _scanned: bool = false
static var _bm: Node = null


# ── Availability ─────────────────────────────────────────────────────────────

static func is_available() -> bool:
	return ClassDB.class_exists(&"GNBlackmagic")


# ── Device discovery ─────────────────────────────────────────────────────────

static func _scan_devices() -> void:
	_scanned = true
	_devices.clear()
	if not is_available():
		return
	_ensure_bm()
	if _bm == null:
		return
	var count: int = _bm.call("get_device_count")
	for i in range(count):
		_devices.append(_bm.call("get_device_info", i))


static func get_device_menu() -> PackedStringArray:
	if not _scanned:
		_scan_devices()
	var items := PackedStringArray(["No Device"])
	for dev: Dictionary in _devices:
		items.append(str(dev.get("name", "Unknown DeckLink")))
	return items


static func get_device_count() -> int:
	if not _scanned:
		_scan_devices()
	return _devices.size()


static func get_device_info(index: int) -> Dictionary:
	var dev_idx := index - 1  # 0 = "No Device"
	if dev_idx < 0 or dev_idx >= _devices.size():
		return {}
	return _devices[dev_idx]


static func get_input_device_menu() -> PackedStringArray:
	if not _scanned:
		_scan_devices()
	var items := PackedStringArray(["No Device"])
	for dev: Dictionary in _devices:
		if dev.get("supports_input", false):
			items.append(str(dev.get("name", "Unknown DeckLink")))
	return items


static func get_output_device_menu() -> PackedStringArray:
	if not _scanned:
		_scan_devices()
	var items := PackedStringArray(["No Device"])
	for dev: Dictionary in _devices:
		if dev.get("supports_output", false):
			items.append(str(dev.get("name", "Unknown DeckLink")))
	return items


static func rescan() -> void:
	_scanned = false
	_devices.clear()


static func get_native() -> Node:
	_ensure_bm()
	return _bm


# ── Internal ─────────────────────────────────────────────────────────────────

static func _ensure_bm() -> void:
	if _bm != null:
		return
	if not is_available():
		return
	_bm = ClassDB.instantiate(&"GNBlackmagic")
