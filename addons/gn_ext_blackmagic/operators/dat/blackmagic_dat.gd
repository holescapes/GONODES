class_name BlackmagicDAT
extends GNDatBase
## Enumerate Blackmagic DeckLink devices and query info as a DAT table.
##
## Outputs a table with one row per detected DeckLink device showing
## name, model, input/output support, and max resolution.

var _bm: Node = null


func _init() -> void:
	node_type = "blackmagic"
	node_description = "Blackmagic DeckLink device enumeration and info table."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Device info table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_pulse("rescan",
		"Rescan", "Re-enumerate connected DeckLink devices"))


func _pre_cook(_delta: float) -> void:
	if get_param_value("rescan"):
		mark_dirty()


func _cook(_inputs: Array[GNData]) -> GNData:
	var out: GNTableData = _prepare_table()
	out.has_header = true
	out.is_table = true
	out.table.append(PackedStringArray([
		"index", "name", "model", "input", "output", "max_width", "max_height"
	]))

	# Check for native library
	if not ClassDB.class_exists(&"GNBlackmagic"):
		out.table.append(PackedStringArray([
			"—", "GNBlackmagic not available", "Install DeckLink drivers + build GDExtension",
			"—", "—", "—", "—"
		]))
		return out

	if _bm == null:
		_bm = ClassDB.instantiate(&"GNBlackmagic")
		add_child(_bm)

	var count: int = _bm.call("get_device_count")
	if count == 0:
		out.table.append(PackedStringArray([
			"—", "No DeckLink devices found", "Check hardware and drivers",
			"—", "—", "—", "—"
		]))
		return out

	for i in range(count):
		var info: Dictionary = _bm.call("get_device_info", i)
		out.table.append(PackedStringArray([
			str(i),
			str(info.get("name", "Unknown")),
			str(info.get("model", "")),
			"Yes" if info.get("supports_input", false) else "No",
			"Yes" if info.get("supports_output", false) else "No",
			str(info.get("max_width", 0)),
			str(info.get("max_height", 0))
		]))

	return out


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _bm != null:
			_bm.queue_free()
			_bm = null
