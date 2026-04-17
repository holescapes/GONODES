class_name TreeUI
extends GNUiBase
## Tree view widget for PanelTOP.
##
## Builds a tree from a DAT input table. Expects columns: name, parent
## (empty for root items). Optionally a third column for icon index.
## Outputs widget_state: {"selected": <float>} (selected item row index, -1 if none)

var _tree: Tree = null
var _items: Array[TreeItem] = []


func _init() -> void:
	node_type = "tree"


func _init_ports() -> void:
	add_input("dat", GNFamily.Type.DAT, false, "Table: name, parent (row index or empty)")
	add_output("out", GNFamily.Type.UI, "Widget output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("hide_root", true, "Hide Root", "Hide the invisible root item"))
	add_parameter(GNParameter.create_bool("hide_folding", false, "Hide Folding", "Hide fold/expand arrows"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(200, 200), "Min Size", "Minimum widget size"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_tree()

	_tree.hide_root = get_param_value("hide_root")
	_tree.hide_folding = get_param_value("hide_folding")
	var ms: Vector2i = get_param_value("min_size")
	_tree.custom_minimum_size = Vector2(ms.x, ms.y)

	# Rebuild tree from DAT
	_tree.clear()
	_items.clear()
	var root: TreeItem = _tree.create_item()

	if inputs.size() > 0 and inputs[0] is GNTableData:
		var dat: GNTableData = inputs[0] as GNTableData
		# Build items — first pass: create all
		for r in range(dat.num_rows()):
			var item_name: String = dat.cell(r, 0) if dat.num_cols() > 0 else "Item %d" % r
			var parent_str: String = dat.cell(r, 1) if dat.num_cols() > 1 else ""
			var parent_item: TreeItem = root
			if parent_str.is_valid_int():
				var parent_idx: int = parent_str.to_int()
				if parent_idx >= 0 and parent_idx < _items.size():
					parent_item = _items[parent_idx]
			var item: TreeItem = _tree.create_item(parent_item)
			item.set_text(0, item_name)
			_items.append(item)

	# Restore saved selection after items are rebuilt
	if widget_state.has("selected"):
		var saved := int(widget_state["selected"])
		if saved >= 0 and saved < _items.size():
			_items[saved].select(0)

	var selected_idx := -1
	var sel: TreeItem = _tree.get_selected()
	if sel != null:
		selected_idx = _items.find(sel)

	widget_state = {"selected": float(selected_idx)}
	return null


func _ensure_tree() -> void:
	if _tree != null:
		return
	_tree = Tree.new()
	_tree.name = id + "_tree"
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_register_signal(_tree.item_selected, _on_item_selected)
	_control_node = _tree


func _on_item_selected() -> void:
	var sel: TreeItem = _tree.get_selected()
	var idx: int = _items.find(sel) if sel != null else -1
	widget_state["selected"] = float(idx)
	mark_dirty()


func destroy_control_node() -> void:
	_tree = null
	_items.clear()
	super.destroy_control_node()
