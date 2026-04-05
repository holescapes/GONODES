class_name SelectDAT
extends GNDatBase
## Selects rows/columns from a DAT — by wire OR by wireless name reference.
##
## When the 'dat' parameter names a remote DAT, its output is used as
## the source (no wire needed).  When 'dat' is empty, the wired input is
## used instead.  Row/column range filtering applies in both modes.
##
## Matches TouchDesigner's Select DAT: remote reference + subset filter.

var _network_cache: GNNetwork = null


func _init() -> void:
	node_type = "select"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Input table (used when 'dat' is empty)")
	add_output("out", GNFamily.Type.DAT, "Selected subset")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_node_ref("dat", GNFamily.Type.DAT,
		"DAT", "Name (id) of a remote DAT to reference (empty = use wired input)"))
	add_parameter(GNParameter.create_int("row_start", 0, 0, null, "Row Start", "First row index"))
	add_parameter(GNParameter.create_int("row_end", -1, -1, null, "Row End", "Last row index (-1 = end)"))
	add_parameter(GNParameter.create_int("col_start", 0, 0, null, "Col Start", "First column index"))
	add_parameter(GNParameter.create_int("col_end", -1, -1, null, "Col End", "Last column index (-1 = end)"))
	add_parameter(GNParameter.create_bool("include_header", true, "Include Header", "Keep header row in output"))


func _cook(inputs: Array[GNData]) -> GNData:
	# Resolve source: wireless reference takes priority over wired input
	var in_dat: GNTableData = null
	var remote_id: String = get_param_value("dat")

	if not remote_id.is_empty():
		in_dat = _resolve_remote_dat(remote_id)
	else:
		in_dat = inputs[0] as GNTableData if inputs.size() > 0 and inputs[0] is GNTableData else null

	if in_dat == null or not in_dat.is_table:
		if not remote_id.is_empty():
			node_warning = "Remote DAT '%s' not found or has no table output" % remote_id
		else:
			node_warning = ""
		return null

	node_warning = ""

	if _cached_table == null:
		_cached_table = GNTableData.new()
	_cached_table.table.clear()

	var r_start: int = get_param_value("row_start")
	var r_end: int = get_param_value("row_end")
	var c_start: int = get_param_value("col_start")
	var c_end: int = get_param_value("col_end")
	var inc_header: bool = get_param_value("include_header")

	var total_rows: int = in_dat.num_rows()
	var total_cols: int = in_dat.num_cols()

	if r_end < 0:
		r_end = total_rows - 1
	r_end = mini(r_end, total_rows - 1)
	if c_end < 0:
		c_end = total_cols - 1
	c_end = mini(c_end, total_cols - 1)

	# Extract header if requested
	if inc_header and in_dat.has_header:
		var header := PackedStringArray()
		var src_headers: PackedStringArray = in_dat.get_headers()
		for c in range(c_start, c_end + 1):
			header.append(src_headers[c] if c < src_headers.size() else "")
		_cached_table.set_headers(header)
	else:
		_cached_table.has_header = false

	# Extract selected rows and columns
	for r in range(r_start, r_end + 1):
		var row := PackedStringArray()
		for c in range(c_start, c_end + 1):
			row.append(in_dat.cell(r, c))
		_cached_table.append_row(row)

	_cached_table.is_table = true
	return _cached_table


func _resolve_remote_dat(target_id: String) -> GNTableData:
	if _network_cache == null or not is_instance_valid(_network_cache):
		var p = get_parent()
		while p != null and not (p is GNNetwork):
			p = p.get_parent()
		_network_cache = p as GNNetwork
	if _network_cache == null:
		return null
	var target: GNNode = _network_cache.get_node_by_id(target_id)
	if target == null or target.family != GNFamily.Type.DAT:
		return null
	return target.cached_output as GNTableData if target.cached_output is GNTableData else null
