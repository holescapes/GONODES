class_name GNDebugPanel
extends PanelContainer
## Docked debug panel with three tabs:
##   1. Cook Chain — topological order table with status, cook time, active flag
##   2. Active Chains — tree rooted at each sink showing upstream dependencies
##   3. Parameter References — expression cross-references and set_par() writes
##
## Reads from GNCookEngine (last_topo_order, _active_set, _consumer_counts)
## and GNNetwork (connections, expression references). Lives in ui/ — never
## imported by core/ or operators/.

## Reference to the cook engine (set by gn_editor.gd).
var cook_engine: GNCookEngine = null

## Reference to the network (set by gn_editor.gd).
var network: GNNetwork = null

## Emitted when user clicks a node row — editor selects + scrolls to it.
signal node_selected(node_id: String)

# ── UI elements ───────────────────────────────────────────────────────────────

var _tab_container: TabContainer
var _cook_chain_tree: Tree
var _active_chain_tree: Tree
var _param_ref_tree: Tree
var _toolbar: HBoxContainer
var _copy_selected_btn: Button
var _copy_all_btn: Button

## Throttle: update at most every N frames to avoid UI overhead.
const _UPDATE_INTERVAL_FRAMES := 6
var _frame_counter: int = 0

## Sort mode for cook chain tab: "order" (topo) or "time" (descending cook ms).
var _cook_sort_mode: String = "order"


func _init() -> void:
	name = "DebugPanel"
	custom_minimum_size.y = 180
	size_flags_horizontal = SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	sb.content_margin_left = 2.0
	sb.content_margin_right = 2.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(vbox)

	# Toolbar
	_toolbar = HBoxContainer.new()
	_toolbar.size_flags_horizontal = SIZE_EXPAND_FILL

	_copy_selected_btn = Button.new()
	_copy_selected_btn.text = "Copy Selected"
	_copy_selected_btn.tooltip_text = "Copy selected rows to clipboard (Ctrl+C)"
	_copy_selected_btn.flat = true
	_copy_selected_btn.pressed.connect(_copy_selected_rows)
	_toolbar.add_child(_copy_selected_btn)

	_copy_all_btn = Button.new()
	_copy_all_btn.text = "Copy All"
	_copy_all_btn.tooltip_text = "Copy all rows from current tab to clipboard"
	_copy_all_btn.flat = true
	_copy_all_btn.pressed.connect(_copy_all_rows)
	_toolbar.add_child(_copy_all_btn)

	vbox.add_child(_toolbar)

	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_tab_container.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(_tab_container)

	# Tab 1: Cook Chain
	_cook_chain_tree = _create_tree("Cook Chain")
	_cook_chain_tree.columns = 6
	_cook_chain_tree.set_column_title(0, "#")
	_cook_chain_tree.set_column_title(1, "Node")
	_cook_chain_tree.set_column_title(2, "Family")
	_cook_chain_tree.set_column_title(3, "Status")
	_cook_chain_tree.set_column_title(4, "Cook (ms)")
	_cook_chain_tree.set_column_title(5, "Active")
	_cook_chain_tree.column_titles_visible = true
	_cook_chain_tree.set_column_expand(0, false)
	_cook_chain_tree.set_column_custom_minimum_width(0, 36)
	_cook_chain_tree.set_column_expand(2, false)
	_cook_chain_tree.set_column_custom_minimum_width(2, 55)
	_cook_chain_tree.set_column_expand(3, false)
	_cook_chain_tree.set_column_custom_minimum_width(3, 70)
	_cook_chain_tree.set_column_expand(4, false)
	_cook_chain_tree.set_column_custom_minimum_width(4, 70)
	_cook_chain_tree.set_column_expand(5, false)
	_cook_chain_tree.set_column_custom_minimum_width(5, 50)
	_cook_chain_tree.item_activated.connect(_on_cook_chain_activated)

	# Tab 2: Active Chains
	_active_chain_tree = _create_tree("Active Chains")
	_active_chain_tree.columns = 3
	_active_chain_tree.set_column_title(0, "Node")
	_active_chain_tree.set_column_title(1, "Family")
	_active_chain_tree.set_column_title(2, "Cook (ms)")
	_active_chain_tree.column_titles_visible = true
	_active_chain_tree.set_column_expand(1, false)
	_active_chain_tree.set_column_custom_minimum_width(1, 55)
	_active_chain_tree.set_column_expand(2, false)
	_active_chain_tree.set_column_custom_minimum_width(2, 70)
	_active_chain_tree.item_activated.connect(_on_active_chain_activated)

	# Tab 3: Parameter References
	_param_ref_tree = _create_tree("Param Refs")
	_param_ref_tree.columns = 5
	_param_ref_tree.set_column_title(0, "Source Node")
	_param_ref_tree.set_column_title(1, "Parameter")
	_param_ref_tree.set_column_title(2, "Expression")
	_param_ref_tree.set_column_title(3, "References")
	_param_ref_tree.set_column_title(4, "Eval (μs)")
	_param_ref_tree.column_titles_visible = true
	_param_ref_tree.set_column_expand(1, false)
	_param_ref_tree.set_column_custom_minimum_width(1, 90)
	_param_ref_tree.set_column_expand(4, false)
	_param_ref_tree.set_column_custom_minimum_width(4, 65)
	_param_ref_tree.item_activated.connect(_on_param_ref_activated)


func _create_tree(tab_name: String) -> Tree:
	var tree := Tree.new()
	tree.name = tab_name
	tree.size_flags_horizontal = SIZE_EXPAND_FILL
	tree.size_flags_vertical = SIZE_EXPAND_FILL
	tree.allow_reselect = true
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_MULTI
	tree.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_tab_container.add_child(tree)
	return tree


# ═══════════════════════════════════════════════════════════════════════════════
# Update (called by gn_editor.gd after each cook frame)
# ═══════════════════════════════════════════════════════════════════════════════

func update_debug_info() -> void:
	if not visible or cook_engine == null or network == null:
		return

	_frame_counter += 1
	if _frame_counter % _UPDATE_INTERVAL_FRAMES != 0:
		return

	var active_tab := _tab_container.current_tab
	match active_tab:
		0:
			_update_cook_chain()
		1:
			_update_active_chains()
		2:
			_update_param_refs()


# ── Tab 1: Cook Chain ─────────────────────────────────────────────────────────

func _update_cook_chain() -> void:
	_cook_chain_tree.clear()
	var root := _cook_chain_tree.create_item()

	var nodes: Array[GNNode] = cook_engine.last_topo_order
	if _cook_sort_mode == "time":
		nodes = nodes.duplicate()
		nodes.sort_custom(func(a: GNNode, b: GNNode) -> bool:
			return a.cook_time_ms > b.cook_time_ms)

	var active_set: Dictionary = cook_engine._active_set

	for i in range(nodes.size()):
		var node: GNNode = nodes[i]
		var item := _cook_chain_tree.create_item(root)

		# Column 0: cook order
		item.set_text(0, str(i + 1))

		# Column 1: node ID
		item.set_text(1, node.id)

		# Column 2: family
		item.set_text(2, GNFamily.get_family_name(node.family))
		item.set_custom_color(2, GNFamily.get_color(node.family))

		# Column 3: status
		var is_active: bool = active_set.has(node.id)
		if not is_active:
			item.set_text(3, "inactive")
			item.set_custom_color(3, Color(0.5, 0.5, 0.5, 0.6))
		elif node.cook_valid:
			item.set_text(3, "✓ cooked")
			item.set_custom_color(3, Color(0.4, 1.0, 0.4))
		elif not node.dirty:
			item.set_text(3, "— cached")
			item.set_custom_color(3, Color(0.6, 0.6, 0.6))
		else:
			item.set_text(3, "✗ error")
			item.set_custom_color(3, Color(1.0, 0.35, 0.3))

		# Column 4: cook time
		var cook_ms := node.cook_time_ms
		item.set_text(4, "%.2f" % cook_ms)
		if cook_ms < 1.0:
			item.set_custom_color(4, Color(0.4, 1.0, 0.4))
		elif cook_ms < 5.0:
			item.set_custom_color(4, Color(1.0, 0.9, 0.3))
		else:
			item.set_custom_color(4, Color(1.0, 0.35, 0.3))

		# Column 5: active
		item.set_text(5, "yes" if is_active else "no")
		if not is_active:
			item.set_custom_color(5, Color(0.5, 0.5, 0.5, 0.6))
			# Dim all columns for inactive rows
			item.set_custom_color(0, Color(0.5, 0.5, 0.5, 0.6))
			item.set_custom_color(1, Color(0.5, 0.5, 0.5, 0.6))

		# Store node_id as metadata for click-to-select
		item.set_metadata(0, node.id)


# ── Tab 2: Active Chains ─────────────────────────────────────────────────────

func _update_active_chains() -> void:
	_active_chain_tree.clear()
	var root := _active_chain_tree.create_item()

	# Build upstream map: node_id → [upstream_node_ids]
	var upstream_map: Dictionary = {}
	for conn in network.connections:
		var from_id: String = conn.from_node
		var to_id: String = conn.to_node
		if to_id.is_empty() or from_id.is_empty():
			continue
		if not upstream_map.has(to_id):
			upstream_map[to_id] = []
		if from_id not in upstream_map[to_id]:
			upstream_map[to_id].append(from_id)

	# Root each tree at a sink node
	var sinks: Array[String] = cook_engine.active_sinks.duplicate()

	# Also include structural sinks (is_sink nodes like WindowOUT)
	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]
		if node.is_sink and node_id not in sinks:
			sinks.append(node_id)

	for sink_id in sinks:
		var sink_node: GNNode = network.nodes.get(sink_id, null)
		if sink_node == null:
			continue
		var visited: Dictionary = {}
		_build_chain_tree(root, sink_id, sink_node, upstream_map, visited)


func _build_chain_tree(parent_item: TreeItem, node_id: String, node: GNNode,
		upstream_map: Dictionary, visited: Dictionary) -> void:
	if visited.has(node_id):
		return
	visited[node_id] = true

	var item := _active_chain_tree.create_item(parent_item)

	var label := "%s (%s)" % [node_id, node.node_type]
	if node.time_dependent:
		label += " ⟳"
	item.set_text(0, label)

	item.set_text(1, GNFamily.get_family_name(node.family))
	item.set_custom_color(1, GNFamily.get_color(node.family))

	var cook_ms := node.cook_time_ms
	if not node.dirty and cook_ms == 0.0:
		item.set_text(2, "cached")
		item.set_custom_color(2, Color(0.6, 0.6, 0.6))
	else:
		item.set_text(2, "%.2f" % cook_ms)
		if cook_ms < 1.0:
			item.set_custom_color(2, Color(0.4, 1.0, 0.4))
		elif cook_ms < 5.0:
			item.set_custom_color(2, Color(1.0, 0.9, 0.3))
		else:
			item.set_custom_color(2, Color(1.0, 0.35, 0.3))

	item.set_metadata(0, node_id)

	# Recurse upstream
	var ups: Array = upstream_map.get(node_id, [])
	for up_id in ups:
		var up_node: GNNode = network.nodes.get(up_id, null)
		if up_node != null:
			_build_chain_tree(item, up_id, up_node, upstream_map, visited)


# ── Tab 3: Parameter References ───────────────────────────────────────────────

func _update_param_refs() -> void:
	_param_ref_tree.clear()
	var root := _param_ref_tree.create_item()

	# Regex for extracting node references from expressions
	var ref_regex := RegEx.new()
	ref_regex.compile("(?:chop[sfi]?|op|top|sop|dat|mat|par[sfi]?|set_par)\\s*\\(\\s*\"([^\"]+)\"")

	var set_par_regex := RegEx.new()
	set_par_regex.compile("set_par\\s*\\(\\s*\"([^\"]+)\"")

	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]
		for param_name in node.parameters:
			var param: GNParameter = node.parameters[param_name]

			# Only show params with expression mode
			if param.mode != GNParameter.Mode.EXPRESSION or param.expression.is_empty():
				continue

			var item := _param_ref_tree.create_item(root)

			# Column 0: source node
			item.set_text(0, node_id)

			# Column 1: parameter name
			item.set_text(1, param_name)

			# Column 2: expression (truncated)
			var expr_text: String = param.expression
			if expr_text.length() > 50:
				expr_text = expr_text.left(47) + "..."
			item.set_text(2, expr_text)

			# Column 3: references
			var refs: Array[String] = []
			var read_results := ref_regex.search_all(param.expression)
			for m in read_results:
				var ref_id := m.get_string(1)
				if ref_id != node_id and ref_id not in refs:
					refs.append("→ " + ref_id)
			var write_results := set_par_regex.search_all(param.expression)
			for m in write_results:
				var ref_id := m.get_string(1)
				if ref_id not in refs:
					refs.append("← ✎ " + ref_id)
			item.set_text(3, ", ".join(refs) if not refs.is_empty() else "—")
			if not refs.is_empty():
				item.set_custom_color(3, Color(0.2, 0.85, 0.95))

			# Column 4: eval time
			var eval_us := param.expression_eval_avg_usec
			item.set_text(4, "%.1f" % eval_us if eval_us > 0.0 else "—")
			if eval_us > 100.0:
				item.set_custom_color(4, Color(1.0, 0.35, 0.3))
			elif eval_us > 20.0:
				item.set_custom_color(4, Color(1.0, 0.9, 0.3))

			item.set_metadata(0, node_id)


# ═══════════════════════════════════════════════════════════════════════════════
# Click-to-select handlers
# ═══════════════════════════════════════════════════════════════════════════════

func _on_cook_chain_activated() -> void:
	_emit_selected_from_tree(_cook_chain_tree)

func _on_active_chain_activated() -> void:
	_emit_selected_from_tree(_active_chain_tree)

func _on_param_ref_activated() -> void:
	_emit_selected_from_tree(_param_ref_tree)

func _emit_selected_from_tree(tree: Tree) -> void:
	var selected := tree.get_selected()
	if selected == null:
		return
	var node_id: Variant = selected.get_metadata(0)
	if node_id is String and not (node_id as String).is_empty():
		node_selected.emit(node_id as String)


# ═══════════════════════════════════════════════════════════════════════════════
# Sort toggle (cook chain tab)
# ═══════════════════════════════════════════════════════════════════════════════

func toggle_cook_sort() -> void:
	_cook_sort_mode = "time" if _cook_sort_mode == "order" else "order"
	_update_cook_chain()


# ═══════════════════════════════════════════════════════════════════════════════
# Clipboard
# ═══════════════════════════════════════════════════════════════════════════════

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C and event.ctrl_pressed:
			_copy_selected_rows()
			get_viewport().set_input_as_handled()


func _copy_selected_rows() -> void:
	var tree := _get_active_tree()
	if tree == null:
		return
	var lines: PackedStringArray = []
	# Header
	if tree.column_titles_visible:
		var header: PackedStringArray = []
		for col in range(tree.columns):
			header.append(tree.get_column_title(col))
		lines.append("\t".join(header))
	# Selected rows
	var item: TreeItem = tree.get_next_selected(null)
	while item != null:
		lines.append(_item_to_tsv(item, tree.columns))
		item = tree.get_next_selected(item)
	if lines.size() <= 1:
		return  # nothing selected (only header)
	DisplayServer.clipboard_set("\n".join(lines))


func _copy_all_rows() -> void:
	var tree := _get_active_tree()
	if tree == null:
		return
	var lines: PackedStringArray = []
	# Header
	if tree.column_titles_visible:
		var header: PackedStringArray = []
		for col in range(tree.columns):
			header.append(tree.get_column_title(col))
		lines.append("\t".join(header))
	# All rows (recursive for Active Chains tree)
	var root := tree.get_root()
	if root != null:
		_collect_items_recursive(root, tree.columns, lines, 0)
	if lines.size() <= 1:
		return  # empty table
	DisplayServer.clipboard_set("\n".join(lines))


func _get_active_tree() -> Tree:
	match _tab_container.current_tab:
		0: return _cook_chain_tree
		1: return _active_chain_tree
		2: return _param_ref_tree
	return null


func _item_to_tsv(item: TreeItem, col_count: int) -> String:
	var cols: PackedStringArray = []
	for col in range(col_count):
		cols.append(item.get_text(col))
	return "\t".join(cols)


func _collect_items_recursive(parent: TreeItem, col_count: int,
		lines: PackedStringArray, depth: int) -> void:
	var child := parent.get_first_child()
	while child != null:
		var prefix := "  ".repeat(depth) if depth > 0 else ""
		var cols: PackedStringArray = []
		for col in range(col_count):
			var text := child.get_text(col)
			if col == 0 and not prefix.is_empty():
				text = prefix + text
			cols.append(text)
		lines.append("\t".join(cols))
		_collect_items_recursive(child, col_count, lines, depth + 1)
		child = child.get_next()
