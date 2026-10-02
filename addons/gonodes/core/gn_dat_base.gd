class_name GNDatBase
extends GNNode
## Base class for all DAT (Data Operator) family operators.
##
## Provides:
##   • family = GNFamily.Type.DAT set automatically
##   • Default output port "out" of type DAT
##   • Cached GNTableData with _prepare_table() helper
##   • Input validation via _get_input_dat()
##   • Inline table preview (create_preview_control / update_preview_control)

# ─── Shared DAT Infrastructure ─────────────────────────────────────────────────

## Reusable output data object (created once, cleared as needed).
var _cached_table: GNTableData = null


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.DAT


## Ensures family is set even when subclass _init() doesn't call super().
func initialize(p_id: String) -> void:
	if family != GNFamily.Type.NET:
		family = GNFamily.Type.DAT
	super.initialize(p_id)


func _is_family_data(data: GNData) -> bool:
	return data is GNTableData


## Default output port.  Override in subclass to add inputs or extra outputs.
func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Table output")


# ═══════════════════════════════════════════════════════════════════════════════
# Output Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Creates the cached table data if it doesn't exist, and optionally clears it.
## Call at the top of _cook() to get a clean slate for table output.
## Set [param clear] to false if you want to append incrementally.
func _prepare_table(clear: bool = true) -> GNTableData:
	if _cached_table == null:
		_cached_table = GNTableData.new()
	elif clear:
		_cached_table.table.clear()
	return _cached_table


# ═══════════════════════════════════════════════════════════════════════════════
# Input Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Safely extracts a GNTableData from the inputs array at [param port].
## Returns null if the port doesn't exist or the data is not GNTableData.
func _get_input_dat(inputs: Array[GNData], port: int = 0) -> GNTableData:
	if port < inputs.size() and inputs[port] is GNTableData:
		var _ret0 := inputs[port] as GNTableData
		return _ret0
	return null


static func _populate_viewer_tree(tree: Tree, tbl: GNTableData) -> void:
	tree.clear()
	var row_count: int = tbl.table.size()
	var col_count: int = 0
	for row in tbl.table:
		if row.size() > col_count:
			col_count = row.size()
	if col_count == 0:
		return
	tree.columns = col_count
	var root := tree.create_item()
	var start_row: int = 0
	if tbl.has_header and row_count > 0:
		for c in range(mini(tbl.table[0].size(), col_count)):
			tree.set_column_title(c, str(tbl.table[0][c]))
			tree.set_column_title_alignment(c, HORIZONTAL_ALIGNMENT_LEFT)
		tree.set_column_titles_visible(true)
		start_row = 1
	else:
		tree.set_column_titles_visible(false)
	for r in range(start_row, row_count):
		var item := tree.create_item(root)
		for c in range(mini(tbl.table[r].size(), col_count)):
			item.set_text(c, str(tbl.table[r][c]))



