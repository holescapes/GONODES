class_name FIFODAT
extends GNDatBase
## First-in-first-out row buffer.
## Accumulates rows from the input table across cooks, maintaining a
## rolling window of the most recent rows up to max_rows.


## Accumulated row buffer persisted across cooks.
var _buffer: Array[PackedStringArray] = []

## Cached header from input (kept in sync each cook).
var _cached_headers: PackedStringArray = PackedStringArray()


func _init() -> void:
	node_type = "fifo"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Input table (new rows appended each cook)")
	add_output("out", GNFamily.Type.DAT, "Accumulated row buffer")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("max_rows", 100, 1, 10000,
		"Max Rows", "Maximum number of rows to keep in the buffer"))
	add_parameter(GNParameter.create_bool("active", true,
		"Active", "When off, stop accumulating new rows"))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_table(false)  # Don't clear — we manage the buffer ourselves
	var in_dat: GNTableData = _get_input_dat(inputs, 0)
	var active: bool = get_param_value("active")
	var max_rows: int = get_param_value("max_rows")

	if in_dat != null and in_dat.is_table and active:
		# Update cached headers from input
		if in_dat.has_header and in_dat.table.size() > 0:
			_cached_headers = in_dat.table[0].duplicate()

		# Append new data rows (skip header row)
		var data_start: int = 1 if in_dat.has_header else 0
		for r in range(data_start, in_dat.table.size()):
			_buffer.append(in_dat.table[r].duplicate())

		# Trim oldest rows if over limit
		while _buffer.size() > max_rows:
			_buffer.remove_at(0)

	# Build output table from buffer
	out.table.clear()
	out.is_table = true
	if not _cached_headers.is_empty():
		out.has_header = true
		out.table.append(_cached_headers)
	else:
		out.has_header = false

	for row in _buffer:
		out.table.append(row)

	return out
