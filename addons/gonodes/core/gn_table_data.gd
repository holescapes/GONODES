class_name GNTableData
extends GNData
## Output data type for DAT operators.
## Holds a 2D table of strings (rows × columns) with optional header row,
## plus a plain-text buffer for text-mode DATs.
## RefCounted (inherits from GNData) — transient compute result.

## Table storage: array of rows, each row is an array of String cells.
## Row 0 is typically the header row when [member has_header] is true.
var table: Array[PackedStringArray] = []

## Whether the first row should be treated as column headers.
var has_header: bool = true

## Plain text content (for text-mode DATs like TextDAT, ScriptDAT).
var text: String = ""

## Whether this DAT is in table mode (true) or text mode (false).
var is_table: bool = true


func get_family() -> int:
	return GNFamily.Type.DAT


func get_preview_text() -> String:
	if not is_table:
		if text.is_empty():
			return "(empty)"
		var lines := text.split("\n", true, 4)
		if lines.size() > 3:
			lines.resize(3)
			lines.append("…")
		return "\n".join(lines)
	if table.is_empty():
		return "(empty)"
	var lines := PackedStringArray()
	if has_header and table.size() > 0:
		lines.append(" | ".join(table[0]))
	var data_start: int = 1 if has_header else 0
	var max_rows: int = mini(table.size() - data_start, 3)
	for r in range(max_rows):
		lines.append(" | ".join(table[data_start + r]))
	if table.size() - data_start > 3:
		lines.append("… +%d rows" % (table.size() - data_start - 3))
	return "\n".join(lines)


func get_data_summary() -> String:
	return "%d×%d" % [num_rows(), num_cols()]


# ─── Table Dimensions ─────────────────────────────────────────────────────────

## Returns the number of rows (excluding header if present).
func num_rows() -> int:
	var total: int = table.size()
	if has_header and total > 0:
		return total - 1
	return total


## Returns the number of columns (from header row or first data row).
func num_cols() -> int:
	if table.is_empty():
		return 0
	return table[0].size()


# ─── Cell Access ───────────────────────────────────────────────────────────────

## Returns the cell value at [param row], [param col].
## Row index is 0-based relative to data rows (skips header automatically).
func cell(row: int, col: int) -> String:
	var actual_row: int = row + (1 if has_header else 0)
	if actual_row < 0 or actual_row >= table.size():
		return ""
	if col < 0 or col >= table[actual_row].size():
		return ""
	return table[actual_row][col]


## Sets a cell value at [param row], [param col].
func set_cell(row: int, col: int, value: String) -> void:
	var actual_row: int = row + (1 if has_header else 0)
	if actual_row < 0 or actual_row >= table.size():
		return
	if col < 0 or col >= table[actual_row].size():
		return
	table[actual_row][col] = value


## Returns a cell by column name (header lookup) and row index.
func cell_by_name(row: int, col_name: String) -> String:
	var col_idx: int = _col_index(col_name)
	if col_idx < 0:
		return ""
	return cell(row, col_idx)


# ─── Row / Column Access ──────────────────────────────────────────────────────

## Returns the header row (column names), or empty array if no header.
func get_headers() -> PackedStringArray:
	if not has_header or table.is_empty():
		return PackedStringArray()
	return table[0]


## Returns a full data row as a PackedStringArray.
func get_row(row: int) -> PackedStringArray:
	var actual_row: int = row + (1 if has_header else 0)
	if actual_row < 0 or actual_row >= table.size():
		return PackedStringArray()
	return table[actual_row]


## Returns all values in a column by index.
func get_col(col: int) -> PackedStringArray:
	var result := PackedStringArray()
	var start: int = 1 if has_header else 0
	for r in range(start, table.size()):
		if col < table[r].size():
			result.append(table[r][col])
		else:
			result.append("")
	return result


## Returns all values in a column by header name.
func get_col_by_name(col_name: String) -> PackedStringArray:
	var idx: int = _col_index(col_name)
	if idx < 0:
		return PackedStringArray()
	return get_col(idx)


# ─── Expression Access ──────────────────────────────────────────────────────────

func get_expression_value(key: String, index: int = -1) -> Variant:
	match key:
		"nrows", "num_rows":
			return num_rows()
		"ncols", "num_cols":
			return num_cols()
		"has_header":
			return 1.0 if has_header else 0.0
		"is_table":
			return 1.0 if is_table else 0.0
		"text_length":
			return text.length()
	# Cell access: key = "row:col" e.g. "0:1" or "0:name"
	if key.contains(":"):
		var parts := key.split(":")
		if parts.size() == 2:
			var row_str := parts[0]
			var col_str := parts[1]
			var row := row_str.to_int() if row_str.is_valid_int() else 0
			if col_str.is_valid_int():
				return cell(row, col_str.to_int()).to_float()
			else:
				return cell_by_name(row, col_str).to_float()
	return 0.0


func get_expression_info() -> Dictionary:
	return {
		"nrows": num_rows(),
		"ncols": num_cols(),
		"has_header": has_header,
		"is_table": is_table,
		"text_length": text.length(),
	}


func get_completions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in ["nrows", "ncols", "has_header", "is_table", "text_length"]:
		result.append({"label": key, "kind": "member"})
	for h in get_headers():
		result.append({"label": h, "kind": "member"})
	return result


# ─── Table Building ───────────────────────────────────────────────────────────

## Sets the header row. Clears existing data rows.
func set_headers(headers: PackedStringArray) -> void:
	table.clear()
	table.append(headers)
	has_header = true
	is_table = true


## Appends a data row. Must match column count.
func append_row(row: PackedStringArray) -> void:
	table.append(row)


## Creates a table with the given dimensions, filled with empty strings.
func create_empty(rows: int, cols: int, headers: PackedStringArray = PackedStringArray()) -> void:
	table.clear()
	is_table = true
	if not headers.is_empty():
		has_header = true
		table.append(headers)
	else:
		has_header = false
	for _r in range(rows):
		var row := PackedStringArray()
		row.resize(cols)
		table.append(row)


## Sets plain text content and switches to text mode.
func set_text(content: String) -> void:
	text = content
	is_table = false


# ─── Conversion ────────────────────────────────────────────────────────────────

## Converts the table to a tab-separated string (for display/export).
func to_tsv() -> String:
	var lines := PackedStringArray()
	for row in table:
		lines.append("\t".join(row))
	return "\n".join(lines)


## Parses a tab-separated string into the table.
func from_tsv(tsv: String, first_row_header: bool = true) -> void:
	table.clear()
	has_header = first_row_header
	is_table = true
	var lines: PackedStringArray = tsv.split("\n")
	for line in lines:
		if line.is_empty():
			continue
		table.append(PackedStringArray(line.split("\t")))


## Returns cell value as float (0.0 if not a valid number).
func cell_as_float(row: int, col: int) -> float:
	var val: String = cell(row, col)
	if val.is_valid_float():
		return val.to_float()
	return 0.0


# ─── Duplication ───────────────────────────────────────────────────────────────

func invalidate() -> void:
	super.invalidate()
	table.clear()
	text = ""


func duplicate_data() -> GNData:
	var copy := GNTableData.new()
	copy.valid = valid
	copy.timestamp = timestamp
	copy.has_header = has_header
	copy.is_table = is_table
	copy.text = text
	for row in table:
		copy.table.append(row.duplicate())
	return copy


func get_export_filters() -> Array[Dictionary]:
	return [
		{"filter": "*.csv", "description": "CSV"},
		{"filter": "*.json", "description": "JSON"},
		{"filter": "*.txt", "description": "Plain Text"},
	]


func export_to_file(path: String) -> Error:
	var ext := path.get_extension().to_lower()
	match ext:
		"json":
			var result: Array = []
			if is_table:
				var headers: PackedStringArray = table[0] if has_header and not table.is_empty() else PackedStringArray()
				var start_row := 1 if has_header else 0
				for r in range(start_row, table.size()):
					var row_dict := {}
					for c in range(table[r].size()):
						var key: String = headers[c] if c < headers.size() else ("col%d" % c)
						row_dict[key] = table[r][c]
					result.append(row_dict)
			var json_str := JSON.stringify(result, "\t")
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f == null:
				return FileAccess.get_open_error()
			f.store_string(json_str if is_table else text)
			f.close()
			return OK
		"txt":
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f == null:
				return FileAccess.get_open_error()
			if is_table:
				for row in table:
					f.store_line("\t".join(row))
			else:
				f.store_string(text)
			f.close()
			return OK
		_:
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f == null:
				return FileAccess.get_open_error()
			for row in table:
				f.store_csv_line(row)
			f.close()
			return OK


# ─── Internal ──────────────────────────────────────────────────────────────────

## Returns the column index for a header name, or -1 if not found.
func _col_index(col_name: String) -> int:
	if not has_header or table.is_empty():
		return -1
	for i in range(table[0].size()):
		if table[0][i] == col_name:
			return i
	return -1
