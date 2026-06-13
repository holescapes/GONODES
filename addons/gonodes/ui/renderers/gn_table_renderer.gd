class_name GNTableRenderer
extends GNDataRenderer
## Renders GNTableData in the viewer (spreadsheet Tree control).
## Nodes that implement table_cell_edited(row, col, value) get inline cell editing.

## Shared read-only Tree for non-editable DATs.
static var _viewer_spreadsheet: Tree = null

## Per-node editable Trees keyed by node id (only allocated when needed).
static var _edit_trees: Dictionary = {}

## Tracks which trees are currently mid-edit (cell editor open).
static var _editing_active: Dictionary = {}

## Tracks which node id has its data callback wired on its edit tree.
static var _data_callback_for: Dictionary = {}

## Shared TextEdit for plain-text DATs that are editable.
static var _text_edit: TextEdit = null


static func _ensure_viewer_spreadsheet() -> Tree:
	if _viewer_spreadsheet == null:
		_viewer_spreadsheet = Tree.new()
		_viewer_spreadsheet.columns = 1
		_viewer_spreadsheet.hide_root = true
		_viewer_spreadsheet.allow_reselect = false
		_viewer_spreadsheet.scroll_horizontal_enabled = true
		_viewer_spreadsheet.scroll_vertical_enabled = true
	return _viewer_spreadsheet


static func _ensure_edit_tree(node_id: String) -> Tree:
	if not _edit_trees.has(node_id):
		var t := Tree.new()
		t.columns = 1
		t.hide_root = true
		t.allow_reselect = true
		t.scroll_horizontal_enabled = true
		t.scroll_vertical_enabled = true
		# Track when user clicks a cell (starts editing intent)
		var nid := node_id  # capture for closure
		t.item_selected.connect(func() -> void:
			_editing_active[nid] = true
		)
		t.nothing_selected.connect(func() -> void:
			_editing_active.erase(nid)
		)
		_edit_trees[node_id] = t
	return _edit_trees[node_id]


static func _ensure_text_edit() -> TextEdit:
	if _text_edit == null:
		_text_edit = TextEdit.new()
		_text_edit.syntax_highlighter = null
		_text_edit.add_theme_font_size_override("font_size", 12)
	return _text_edit


func render_for_viewer(data: GNData, viewer) -> void:
	if not (data is GNTableData):
		viewer.set_info("No DAT output", "")
		return
	var tbl: GNTableData = data as GNTableData
	var node: GNNode = viewer._displayed_node.get_ref() as GNNode
	var editable: bool = node != null and node.has_method("table_cell_edited")

	if not tbl.is_table:
		# Plain text mode
		if editable:
			var te := _ensure_text_edit()
			# Don't clobber text while user is typing
			if te.has_focus():
				return
			# Reconnect signal fresh each time
			for conn in te.text_changed.get_connections():
				te.text_changed.disconnect(conn.callable)
			var weak_node := weakref(node)
			if te.get_parent() != null:
				te.get_parent().remove_child(te)
			if te.text != tbl.text:
				te.text = tbl.text
			te.text_changed.connect(func() -> void:
				var n: GNNode = weak_node.get_ref() as GNNode
				if n != null:
					n.table_cell_edited(-1, -1, te.text)
			)
			viewer.set_control(te, "DAT")
		else:
			if tbl.text.is_empty():
				viewer.set_info("(empty text)", "DAT")
			else:
				viewer.set_info(tbl.text, "DAT")
		return

	if tbl.table.is_empty():
		viewer.set_info("No DAT output", "")
		return

	if editable:
		var tree := _ensure_edit_tree(node.id)
		_populate_edit_tree(tree, tbl, node)
		viewer.set_control(tree, "%d rows" % (tbl.table.size() - (1 if tbl.has_header else 0)))
	else:
		var tree := _ensure_viewer_spreadsheet()
		_populate_viewer_tree(tree, tbl)
		viewer.set_control(tree, "%d rows" % (tbl.table.size() - (1 if tbl.has_header else 0)))


## Populates a read-only Tree from GNTableData.
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


## Populates an editable Tree and wires item_edited back to node.table_cell_edited.
## Skips rebuild while a cell is actively being edited to avoid clobbering input.
static func _populate_edit_tree(tree: Tree, tbl: GNTableData, node: GNNode) -> void:
	# Skip rebuild while user is mid-edit (cell selected / editor open).
	if _editing_active.has(node.id):
		return

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
		item.set_metadata(0, r - start_row)  # 0-based data row index
		for c in range(mini(tbl.table[r].size(), col_count)):
			item.set_text(c, str(tbl.table[r][c]))
			item.set_editable(c, true)

	# Wire the data callback once per node (not every rebuild).
	if not _data_callback_for.has(node.id):
		var weak_node := weakref(node)
		var nid := node.id
		tree.item_edited.connect(func() -> void:
			_editing_active.erase(nid)  # editing finished
			var sel: TreeItem = tree.get_edited()
			if sel == null:
				return
			var col: int = tree.get_edited_column()
			var data_row: int = int(sel.get_metadata(0))
			var value: String = sel.get_text(col)
			var n: GNNode = weak_node.get_ref() as GNNode
			if n != null:
				n.table_cell_edited(data_row, col, value)
		)
		_data_callback_for[node.id] = true
