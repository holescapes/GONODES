class_name GNTableRenderer
extends GNDataRenderer
## Renders GNTableData in the viewer (spreadsheet Tree control).

## Shared Tree control for spreadsheet display.
static var _viewer_spreadsheet: Tree = null


static func _ensure_viewer_spreadsheet() -> Tree:
	if _viewer_spreadsheet == null:
		_viewer_spreadsheet = Tree.new()
		_viewer_spreadsheet.columns = 1
		_viewer_spreadsheet.hide_root = true
		_viewer_spreadsheet.allow_reselect = false
		_viewer_spreadsheet.scroll_horizontal_enabled = true
		_viewer_spreadsheet.scroll_vertical_enabled = true
	return _viewer_spreadsheet


func render_for_viewer(data: GNData, viewer) -> void:
	if data is GNTableData:
		var tbl: GNTableData = data as GNTableData
		if not tbl.table.is_empty():
			var tree := _ensure_viewer_spreadsheet()
			_populate_viewer_tree(tree, tbl)
			viewer.set_control(tree)
			return
	viewer.set_info("No DAT output", "")


func render_for_preview(data: GNData, host) -> void:
	if data != null and host.has_method("set_text"):
		host.set_text(data.get_preview_text())
	elif host.has_method("set_text"):
		host.set_text("")


## Populates a Tree control from GNTableData rows/columns.
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
