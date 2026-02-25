class_name GNParamInspector
extends PanelContainer
## Parameter inspector panel for a selected GNNode.
## Shows a header with node info, then a scrollable list of GNParamRow widgets
## for each parameter. Live-edits flow instantly to the cook engine.

## Currently inspected node (or null).
var _current_node: GNNode = null

## Map of param_name → GNParamRow for the current node.
var _param_rows: Dictionary = {}

## Reference to the network (for expression context display).
var network: GNNetwork = null

## UI elements
var _scroll: ScrollContainer = null
var _vbox: VBoxContainer = null
var _header_label: Label = null
var _family_bar: ColorRect = null
var _status_label: Label = null
var _no_selection_label: Label = null


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	custom_minimum_size = Vector2(260, 0)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	# Family color bar (thin strip at top)
	_family_bar = ColorRect.new()
	_family_bar.custom_minimum_size = Vector2(0, 4)
	_family_bar.color = Color(0.3, 0.3, 0.3)
	root_vbox.add_child(_family_bar)

	# Header section
	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 2)

	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 8)
	header_margin.add_theme_constant_override("margin_right", 8)
	header_margin.add_theme_constant_override("margin_top", 6)
	header_margin.add_theme_constant_override("margin_bottom", 4)
	header_margin.add_child(header_box)
	root_vbox.add_child(header_margin)

	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", 14)
	_header_label.add_theme_color_override("font_color", Color(1, 1, 1))
	header_box.add_child(_header_label)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header_box.add_child(_status_label)

	# Separator
	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# Scroll area for parameters
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(_scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 2)
	_scroll.add_child(_vbox)

	# "No selection" placeholder
	_no_selection_label = Label.new()
	_no_selection_label.text = "Select a node to inspect"
	_no_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_selection_label.add_theme_font_size_override("font_size", 12)
	_no_selection_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_no_selection_label.size_flags_vertical = SIZE_EXPAND_FILL

	# Add margin for the placeholder
	var placeholder_margin := MarginContainer.new()
	placeholder_margin.add_theme_constant_override("margin_top", 40)
	placeholder_margin.add_child(_no_selection_label)
	_vbox.add_child(placeholder_margin)

	_show_empty_state()


# ═══════════════════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════════════════

## Inspects a node by ID. Looks up in the bound network.
func inspect_node(node_id: String) -> void:
	if network == null:
		return
	var node: GNNode = network.get_node_by_id(node_id)
	if node == null:
		clear_inspection()
		return
	inspect(node)


## Inspects the given GNNode, building param rows for all its parameters.
func inspect(node: GNNode) -> void:
	if _current_node == node:
		return  # Already inspecting this node

	_clear_rows()
	_current_node = node

	if _current_node == null:
		_show_empty_state()
		return

	# Update header
	var family_name := GNFamily.get_family_name(node.family)
	var family_color := GNFamily.get_color(node.family)
	_header_label.text = "%s" % node.id
	_status_label.text = "%s  |  %s  |  %din %dout" % [
		family_name, node.node_type,
		node.input_ports.size(), node.output_ports.size()]
	_family_bar.color = family_color

	# Hide placeholder
	_no_selection_label.get_parent().visible = false

	# Build parameter rows in definition order
	var param_names := node.get_parameter_names()
	for p_name in param_names:
		var param: GNParameter = node.get_parameter(p_name)
		if param == null:
			continue

		var row := GNParamRow.new()
		row.setup(param, node)
		_vbox.add_child(row)
		_param_rows[p_name] = row

	# Connect to node's cooked signal for live status updates
	if not node.node_cooked.is_connected(_on_node_cooked):
		node.node_cooked.connect(_on_node_cooked)

	GNLogger.debug("Inspector", "Inspecting '%s' — %d parameters" % [
		node.id, param_names.size()])


## Clears the inspector (no node selected).
func clear_inspection() -> void:
	_clear_rows()
	_current_node = null
	_show_empty_state()


# ═══════════════════════════════════════════════════════════════════════════════
# Status Updates
# ═══════════════════════════════════════════════════════════════════════════════

## Called after each cook to update status label with cook time.
func _on_node_cooked(node_id: String) -> void:
	if _current_node == null or _current_node.id != node_id:
		return
	_status_label.text = "%s  |  %s  |  %.2fms" % [
		GNFamily.get_family_name(_current_node.family),
		_current_node.node_type,
		_current_node.cook_time_ms]

	# Update expression-mode rows to show resolved values
	for p_name in _param_rows:
		var row: GNParamRow = _param_rows[p_name]
		if row.param and row.param.mode == GNParameter.Mode.EXPRESSION:
			row.update_expression_status()


# ═══════════════════════════════════════════════════════════════════════════════
# Internal
# ═══════════════════════════════════════════════════════════════════════════════

## Removes all current parameter rows.
func _clear_rows() -> void:
	# Disconnect from previous node
	if _current_node and _current_node.node_cooked.is_connected(_on_node_cooked):
		_current_node.node_cooked.disconnect(_on_node_cooked)

	for p_name in _param_rows:
		var row: GNParamRow = _param_rows[p_name]
		row.cleanup()
		_vbox.remove_child(row)
		row.queue_free()
	_param_rows.clear()


## Shows the "no selection" state.
func _show_empty_state() -> void:
	_header_label.text = "Inspector"
	_status_label.text = "No node selected"
	_family_bar.color = Color(0.3, 0.3, 0.3)
	_no_selection_label.get_parent().visible = true
