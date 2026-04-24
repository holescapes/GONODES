class_name JSONDAT
extends GNDatBase
## Parse JSON text into a table or generate JSON from a table.
## Two modes: Parse (string → table) and Generate (table → JSON string).


func _init() -> void:
	node_type = "json"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Input table (for Generate mode)")
	add_output("out", GNFamily.Type.DAT, "Parsed table or JSON text")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Parse", "Generate"]), 0,
		"Mode", "Parse JSON string to table, or generate JSON from table"))
	add_parameter(GNParameter.create_string("json_string", "The json string string",
		"JSON String", "JSON text to parse (Parse mode only)"))
	add_parameter(GNParameter.create_bool("pretty", true,
		"Pretty Print", "Use indented JSON output (Generate mode only)"))


func get_active_input_indices() -> PackedInt32Array:
	var mode: int = get_param_value("mode")
	if mode == 0:
		return PackedInt32Array([-1])  # Parse mode ignores all inputs
	return PackedInt32Array()  # Generate uses all inputs


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_table()
	var mode: int = get_param_value("mode")

	if mode == 0:
		# ── Parse mode ──────────────────────────────────────────────────────
		var json_str: String = get_param_value("json_string")
		if json_str.is_empty():
			return out
		var parsed = JSON.parse_string(json_str)
		if parsed == null:
			push_warning("JSONDAT: Failed to parse JSON string.")
			return out
		_json_to_table(parsed, out)
		return out
	else:
		# ── Generate mode ───────────────────────────────────────────────────
		var in_dat: GNTableData = _get_input_dat(inputs, 0)
		if in_dat == null or not in_dat.is_table:
			return out
		var pretty: bool = get_param_value("pretty")
		var json_text: String = _table_to_json(in_dat, pretty)
		out.is_table = false
		out.set_text(json_text)
		return out


## Converts a parsed JSON value (expected Array of Dicts) into a table.
func _json_to_table(parsed: Variant, tbl: GNTableData) -> void:
	tbl.is_table = true
	tbl.has_header = true
	if parsed is Array and parsed.size() > 0 and parsed[0] is Dictionary:
		var keys: Array = parsed[0].keys()
		var hdr := PackedStringArray()
		for k in keys:
			hdr.append(str(k))
		tbl.set_headers(hdr)
		for item in parsed:
			var row := PackedStringArray()
			for k in keys:
				row.append(str(item.get(k, "")))
			tbl.append_row(row)
	elif parsed is Dictionary:
		tbl.set_headers(PackedStringArray(["key", "value"]))
		for k in parsed.keys():
			tbl.append_row(PackedStringArray([str(k), str(parsed[k])]))


## Converts a table into a JSON string (array of objects).
func _table_to_json(tbl: GNTableData, pretty: bool) -> String:
	var result: Array = []
	var headers: PackedStringArray = tbl.get_headers()
	for r in range(tbl.num_rows()):
		var row: PackedStringArray = tbl.get_row(r)
		var obj: Dictionary = {}
		for c in range(mini(headers.size(), row.size())):
			obj[headers[c]] = row[c]
		result.append(obj)
	if pretty:
		return JSON.stringify(result, "\t")
	return JSON.stringify(result)
