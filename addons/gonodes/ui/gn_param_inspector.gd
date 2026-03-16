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

## Preset toolbar elements
var _preset_bar: HBoxContainer = null
var _preset_dropdown: OptionButton = null
var _copy_btn: Button = null
var _paste_btn: Button = null
var _reset_btn: Button = null
var _presets_btn: MenuButton = null
var _save_preset_dialog: AcceptDialog = null
var _save_preset_line_edit: LineEdit = null

## Cached preset list for the current node (rebuilt when node or dropdown changes).
var _cached_presets: Array = []

## Whether we're programmatically changing the dropdown (suppress signals).
var _updating_dropdown: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Minimum width set in scene (custom_minimum_size on parent PanelContainer)

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

	# Preset toolbar (copy / paste / reset / presets dropdown)
	_preset_bar = HBoxContainer.new()
	_preset_bar.add_theme_constant_override("separation", 4)
	_preset_bar.visible = false  # Hidden until a node is inspected
	header_box.add_child(_preset_bar)

	# Preset dropdown selector
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 4)
	var preset_lbl := Label.new()
	preset_lbl.text = "Preset:"
	preset_lbl.add_theme_font_size_override("font_size", 11)
	preset_row.add_child(preset_lbl)
	_preset_dropdown = OptionButton.new()
	_preset_dropdown.add_theme_font_size_override("font_size", 11)
	_preset_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_dropdown.item_selected.connect(_on_preset_dropdown_selected)
	preset_row.add_child(_preset_dropdown)
	_preset_bar.add_child(preset_row)

	# Buttons row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)

	_copy_btn = Button.new()
	_copy_btn.text = "Copy"
	_copy_btn.tooltip_text = "Copy all parameters to clipboard"
	_copy_btn.add_theme_font_size_override("font_size", 11)
	_copy_btn.custom_minimum_size = Vector2(50, 0)
	_copy_btn.pressed.connect(_on_copy_pressed)
	btn_row.add_child(_copy_btn)

	_paste_btn = Button.new()
	_paste_btn.text = "Paste"
	_paste_btn.tooltip_text = "Paste parameters from clipboard (same operator type)"
	_paste_btn.add_theme_font_size_override("font_size", 11)
	_paste_btn.custom_minimum_size = Vector2(50, 0)
	_paste_btn.pressed.connect(_on_paste_pressed)
	btn_row.add_child(_paste_btn)

	_reset_btn = Button.new()
	_reset_btn.text = "Reset"
	_reset_btn.tooltip_text = "Reset all parameters to factory defaults"
	_reset_btn.add_theme_font_size_override("font_size", 11)
	_reset_btn.custom_minimum_size = Vector2(50, 0)
	_reset_btn.pressed.connect(_on_reset_pressed)
	btn_row.add_child(_reset_btn)

	_presets_btn = MenuButton.new()
	_presets_btn.text = "Presets ▾"
	_presets_btn.tooltip_text = "Save / load parameter presets"
	_presets_btn.add_theme_font_size_override("font_size", 11)
	_presets_btn.flat = false
	_presets_btn.get_popup().id_pressed.connect(_on_preset_menu_id_pressed)
	_presets_btn.get_popup().about_to_popup.connect(_rebuild_presets_menu)
	btn_row.add_child(_presets_btn)
	_preset_bar.add_child(btn_row)

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
		# Same node — just refresh the header (e.g., after rename)
		_header_label.text = "%s" % node.id
		return

	_clear_rows()
	_current_node = node

	if _current_node == null:
		_show_empty_state()
		return

	# Update header
	var family_name := GNFamily.get_family_name(node.family)
	var family_color := GNFamily.get_color(node.family)
	_header_label.text = "%s" % node.id
	var _script := node.get_script()
	var _is_native := _script != null and (_script as GDScript).resource_path.contains("gn_ext_native")
	_status_label.text = "%s  |  %s%s  |  %din %dout" % [
		family_name, node.node_type,
		" [native]" if _is_native else "",
		node.input_ports.size(), node.output_ports.size()]
	_family_bar.color = family_color

	# Hide placeholder
	_no_selection_label.get_parent().visible = false

	# Show preset toolbar and update paste button
	_preset_bar.visible = true
	_paste_btn.disabled = not GNParamPresetManager.can_paste(node)
	_refresh_preset_dropdown()

	# Build parameter rows in definition order.
	# Consecutive params sharing a non-empty display_group are placed
	# side-by-side inside a shared HBoxContainer.
	var param_names := node.get_parameter_names()
	var current_group: String = ""
	var group_hbox: HBoxContainer = null
	var spare_header_added := false
	for p_name in param_names:
		var param: GNParameter = node.get_parameter(p_name)
		if param == null:
			continue

		# Add spare parameters section header
		if not spare_header_added and node.spare_parameters.has(p_name):
			spare_header_added = true
			current_group = ""
			group_hbox = null
			var spare_sep := HSeparator.new()
			spare_sep.add_theme_constant_override("separation", 4)
			_vbox.add_child(spare_sep)
			var spare_label := Label.new()
			spare_label.text = "Spare Parameters"
			spare_label.add_theme_font_size_override("font_size", 12)
			spare_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
			spare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_vbox.add_child(spare_label)

		var row := GNParamRow.new()
		row.network = network
		row.setup(param, node)

		if param.display_group != "" and param.display_group == current_group:
			# Continue the existing group row
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			group_hbox.add_child(row)
		elif param.display_group != "":
			# Start a new group row
			current_group = param.display_group
			group_hbox = HBoxContainer.new()
			group_hbox.add_theme_constant_override("separation", 4)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			group_hbox.add_child(row)
			_vbox.add_child(group_hbox)
		else:
			# Ungrouped — normal full-width row
			current_group = ""
			group_hbox = null
			_vbox.add_child(row)

		_param_rows[p_name] = row

	# Apply lock state — disable all param rows when node is locked
	_apply_lock_state()

	# Connect to node's cooked signal for live status updates
	if not node.node_cooked.is_connected(_on_node_cooked):
		node.node_cooked.connect(_on_node_cooked)

	# Connect to parameters_changed so we auto-refresh when params are shown/hidden
	if not node.parameters_changed.is_connected(_on_parameters_changed):
		node.parameters_changed.connect(_on_parameters_changed)

	GNLogger.debug("Inspector", "Inspecting '%s' — %d parameters" % [
		node.id, param_names.size()])


## Clears the inspector (no node selected).
func clear_inspection() -> void:
	_clear_rows()
	_current_node = null
	_show_empty_state()


## Called when the currently inspected node dynamically changes its parameter set.
## Forces a full rebuild of the parameter rows for the same node.
func _on_parameters_changed(node_id: String) -> void:
	if _current_node == null or _current_node.id != node_id:
		return
	# Force re-inspect by clearing _current_node first
	var node := _current_node
	_current_node = null
	inspect(node)


# ═══════════════════════════════════════════════════════════════════════════════
# Status Updates
# ═══════════════════════════════════════════════════════════════════════════════

## Called after each cook to update status label with cook time.
func _on_node_cooked(node_id: String) -> void:
	if _current_node == null or _current_node.id != node_id:
		return

	var base_text := "%s  |  %s  |  %.2fms" % [
		GNFamily.get_family_name(_current_node.family),
		_current_node.node_type,
		_current_node.cook_time_ms]

	# For TOPs, append output resolution (and input resolutions if connected)
	if _current_node.family == GNFamily.Type.TOP:
		var res_parts: PackedStringArray = []

		# Gather input resolutions
		var in_res: PackedStringArray = []
		for i in range(_current_node.input_ports.size()):
			var label := "in%d" % i
			# Walk network connections to find upstream cached output
			var found := false
			if _current_node.get_parent() is GNCookEngine:
				var engine: GNCookEngine = _current_node.get_parent() as GNCookEngine
				if engine.network:
					var conn: GNConnection = engine.network.get_connection_at_input(_current_node.id, i)
					if conn:
						var upstream: GNNode = engine.network.get_node_by_id(conn.from_node)
						if upstream and upstream.cached_output is GNTextureData:
							var td: GNTextureData = upstream.cached_output as GNTextureData
							in_res.append("%s:%dx%d" % [label, td.resolution.x, td.resolution.y])
							found = true
			if not found:
				in_res.append("%s:--" % label)

		if in_res.size() > 0:
			res_parts.append("In [%s]" % ", ".join(in_res))

		# Output resolution
		if _current_node.cached_output is GNTextureData:
			var out_td: GNTextureData = _current_node.cached_output as GNTextureData
			res_parts.append("Out %dx%d" % [out_td.resolution.x, out_td.resolution.y])
		else:
			res_parts.append("Out --")

		if res_parts.size() > 0:
			base_text += "  |  %s" % "  |  ".join(res_parts)

	_status_label.text = base_text

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
	if _current_node and _current_node.parameters_changed.is_connected(_on_parameters_changed):
		_current_node.parameters_changed.disconnect(_on_parameters_changed)

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
	_preset_bar.visible = false


## Enables or disables parameter rows based on the node's locked state.
func _apply_lock_state() -> void:
	if _current_node == null:
		return
	var is_locked := _current_node.locked
	for p_name in _param_rows:
		var row: GNParamRow = _param_rows[p_name]
		# Disable mouse input and visually dim when locked
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE if is_locked else Control.MOUSE_FILTER_STOP
		row.modulate = Color(0.6, 0.6, 0.6, 0.8) if is_locked else Color.WHITE
		# Recursively set mouse filter on children
		_set_children_mouse_filter(row, Control.MOUSE_FILTER_IGNORE if is_locked else Control.MOUSE_FILTER_STOP)
	# Show lock indicator in status
	if is_locked:
		_status_label.text += "  |  🔒 LOCKED"


## Recursively sets mouse_filter on all Control children.
func _set_children_mouse_filter(node: Control, filter: Control.MouseFilter) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = filter
			_set_children_mouse_filter(child, filter)
	_family_bar.color = Color(0.3, 0.3, 0.3)
	_no_selection_label.get_parent().visible = true


# ═══════════════════════════════════════════════════════════════════════════════
# Preset Toolbar Handlers
# ═══════════════════════════════════════════════════════════════════════════════

## Copy all parameters of the current node to the preset clipboard.
func _on_copy_pressed() -> void:
	if _current_node == null:
		return
	GNParamPresetManager.copy_params(_current_node)
	# Update paste button — may now be pastable
	_paste_btn.disabled = not GNParamPresetManager.can_paste(_current_node)


## Paste parameters from clipboard onto the current node.
func _on_paste_pressed() -> void:
	if _current_node == null:
		return
	var applied := GNParamPresetManager.paste_params(_current_node)
	if applied > 0:
		_current_node.parameters_changed.emit(_current_node.id)


## Reset all parameters to factory defaults.
func _on_reset_pressed() -> void:
	if _current_node == null:
		return
	var count := GNParamPresetManager.reset_to_defaults(_current_node)
	if count > 0:
		_current_node.parameters_changed.emit(_current_node.id)


## Populates and handles the Presets dropdown menu.
func _on_preset_menu_id_pressed(id: int) -> void:
	if _current_node == null:
		return
	const SAVE_ID := 0
	const LOAD_BASE := 100
	const DELETE_BASE := 1000

	if id == SAVE_ID:
		_show_save_preset_dialog()
		return

	if id >= DELETE_BASE:
		# Delete a user preset
		var preset_idx: int = id - DELETE_BASE
		var op_type: String = _current_node.get_script().get_global_name()
		var presets := GNParamPresetManager.get_preset_list(op_type)
		if preset_idx >= 0 and preset_idx < presets.size():
			GNParamPresetManager.delete_preset(presets[preset_idx]["path"])
		return

	if id >= LOAD_BASE:
		# Load a preset
		var preset_idx: int = id - LOAD_BASE
		var op_type: String = _current_node.get_script().get_global_name()
		var presets := GNParamPresetManager.get_preset_list(op_type)
		if preset_idx >= 0 and preset_idx < presets.size():
			var applied := GNParamPresetManager.load_preset(
				_current_node, presets[preset_idx]["path"])
			if applied > 0:
				_current_node.parameters_changed.emit(_current_node.id)


## Called when the Presets MenuButton is about to show — populates items dynamically.
func _rebuild_presets_menu() -> void:
	if _current_node == null:
		return
	var popup: PopupMenu = _presets_btn.get_popup()
	popup.clear()

	const SAVE_ID := 0
	const LOAD_BASE := 100
	const DELETE_BASE := 1000

	popup.add_item("Save Preset…", SAVE_ID)
	popup.add_separator()

	var op_type: String = _current_node.get_script().get_global_name()
	var presets := GNParamPresetManager.get_preset_list(op_type)
	if presets.is_empty():
		popup.add_item("(no saved presets)", -1)
		popup.set_item_disabled(popup.item_count - 1, true)
	else:
		for i in range(presets.size()):
			var entry: Dictionary = presets[i]
			var label: String = entry["name"]
			if entry["is_factory"]:
				label += "  [factory]"
			popup.add_item(label, LOAD_BASE + i)

		# Add delete section for user presets
		var has_user := false
		for entry in presets:
			if not entry["is_factory"]:
				has_user = true
				break
		if has_user:
			popup.add_separator("Delete")
			for i in range(presets.size()):
				var entry: Dictionary = presets[i]
				if not entry["is_factory"]:
					popup.add_item("Delete: %s" % entry["name"], DELETE_BASE + i)


## Shows the save-preset name dialog.
func _show_save_preset_dialog() -> void:
	if _current_node == null:
		return
	if _save_preset_dialog == null:
		_save_preset_dialog = AcceptDialog.new()
		_save_preset_dialog.title = "Save Parameter Preset"
		_save_preset_dialog.ok_button_text = "Save"
		_save_preset_dialog.size = Vector2i(360, 120)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)

		var lbl := Label.new()
		lbl.text = "Preset name:"
		vbox.add_child(lbl)

		_save_preset_line_edit = LineEdit.new()
		_save_preset_line_edit.placeholder_text = "My Preset"
		_save_preset_line_edit.select_all_on_focus = true
		vbox.add_child(_save_preset_line_edit)

		_save_preset_dialog.add_child(vbox)
		_save_preset_dialog.confirmed.connect(_on_save_preset_confirmed)
		add_child(_save_preset_dialog)

	var op_type: String = _current_node.get_script().get_global_name()
	_save_preset_dialog.title = "Save Param Preset — %s" % op_type
	_save_preset_line_edit.text = ""
	_save_preset_line_edit.grab_focus.call_deferred()
	_save_preset_dialog.popup_centered()


## Confirms saving the named preset.
func _on_save_preset_confirmed() -> void:
	var preset_name: String = _save_preset_line_edit.text.strip_edges()
	if preset_name.is_empty() or _current_node == null:
		return
	GNParamPresetManager.save_preset(_current_node, preset_name)
	_refresh_preset_dropdown()


# ═══════════════════════════════════════════════════════════════════════════════
# Preset Dropdown
# ═══════════════════════════════════════════════════════════════════════════════

## Rebuilds the preset OptionButton dropdown for the current node.
func _refresh_preset_dropdown() -> void:
	if _preset_dropdown == null or _current_node == null:
		return
	_updating_dropdown = true
	_preset_dropdown.clear()
	_preset_dropdown.add_item("[Default]")

	var op_type: String = _current_node.get_script().get_global_name()
	_cached_presets = GNParamPresetManager.get_preset_list(op_type)

	for entry in _cached_presets:
		var label: String = entry["name"]
		if entry["is_factory"]:
			label += "  [factory]"
		_preset_dropdown.add_item(label)

	_preset_dropdown.selected = 0
	_updating_dropdown = false


## Called when the user selects a preset from the dropdown.
func _on_preset_dropdown_selected(idx: int) -> void:
	if _updating_dropdown or _current_node == null:
		return
	if idx == 0:
		# "[Default]" selected — reset to factory defaults
		var count := GNParamPresetManager.reset_to_defaults(_current_node)
		if count > 0:
			_current_node.parameters_changed.emit(_current_node.id)
		return
	# Preset entries start at index 1 → _cached_presets index = idx - 1
	var preset_idx: int = idx - 1
	if preset_idx >= 0 and preset_idx < _cached_presets.size():
		var applied := GNParamPresetManager.load_preset(
			_current_node, _cached_presets[preset_idx]["path"])
		if applied > 0:
			_current_node.parameters_changed.emit(_current_node.id)
