class_name GNDepthSensorHelper
## Shared utilities for all depth sensor operators.
##
## Caches the compiled backend list and discovered device list so multiple
## operators avoid repeated GNDepthSensor instantiation and hardware probing.
## Call rescan() to force a fresh device enumeration (e.g. after plugging
## in a new sensor).

# ── Cached state (shared across all operators) ───────────────────────────────

static var _backends: PackedStringArray = PackedStringArray()
static var _backends_queried: bool = false

static var _devices: Array = []  # Array[Dictionary] — {serial, name, backend}
static var _devices_scanned: bool = false


# ── Backend discovery (fast — no I/O, compile-time list) ─────────────────────

## Returns true if the GNDepthSensor native class is loaded.
static func is_available() -> bool:
	return ClassDB.class_exists(&"GNDepthSensor")


## Returns the list of compiled sensor backends (e.g. ["azure_kinect", "realsense"]).
## Queries the C++ layer once and caches the result.  If the GDExtension is
## not loaded, returns an empty array.
static func get_backends() -> PackedStringArray:
	if _backends_queried:
		return _backends
	_backends_queried = true
	if not is_available():
		return _backends
	var sensor: RefCounted = ClassDB.instantiate(&"GNDepthSensor")
	if sensor != null:
		_backends = sensor.get_available_backends()
	return _backends


# ── Device discovery (cached — scans hardware once on first use) ─────────────

## Scans all compiled backends for physically connected sensors.
## Results are cached — call rescan() to refresh.
static func _scan_devices() -> void:
	_devices_scanned = true
	_devices.clear()
	if not is_available():
		return
	var sensor: RefCounted = ClassDB.instantiate(&"GNDepthSensor")
	if sensor == null:
		return
	var raw: Array = sensor.enumerate_devices()
	for dev in raw:
		_devices.append(dev)


## Returns PackedStringArray for a "Device" enum parameter.
## Index 0 is always "First Available" (auto-detect).
## Subsequent entries are discovered devices: "DeviceName (serial)".
static func get_device_menu() -> PackedStringArray:
	if not _devices_scanned:
		_scan_devices()
	var items := PackedStringArray(["First Available"])
	for dev: Dictionary in _devices:
		items.append(dev.get("name", "Unknown Device"))
	return items


## Returns the {serial, name, backend} Dictionary for a device menu index.
## Index 0 ("First Available") returns an empty Dictionary — the operator
## should try the first compiled backend with an empty serial.
static func get_device_at(index: int) -> Dictionary:
	var dev_idx := index - 1  # 0 = "First Available"
	if dev_idx < 0 or dev_idx >= _devices.size():
		return {}
	return _devices[dev_idx]


## Clears all caches and forces a fresh backend + device scan on next access.
static func rescan() -> void:
	_backends_queried = false
	_backends = PackedStringArray()
	_devices_scanned = false
	_devices.clear()


## Rescans hardware and updates a node's "device" enum parameter in-place.
## Call from _pre_cook() when a rescan pulse fires.  After updating the
## enum_options, emits parameters_changed so the inspector rebuilds the
## dropdown with the fresh device list.
static func rescan_and_update_param(node: Node) -> void:
	rescan()
	var device_param: GNParameter = node.get_param("device")
	if device_param == null:
		return
	var prev_index: int = int(device_param.value)
	device_param.enum_options = get_device_menu()
	# Clamp selection to valid range
	if prev_index >= device_param.enum_options.size():
		device_param.value = 0
		device_param.resolved_value = 0
	node.parameters_changed.emit(node.id)
