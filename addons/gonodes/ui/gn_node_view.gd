class_name GNNodeView
extends GraphNode
## Visual representation of a single GNNode operator in the graph editor.
## Shows family-colored title bar, typed port slots, and the node name.
## Double-click the title bar to rename the node.
## One GNNodeView per GNNode in the network.


## The GNNode this view represents.
var gn_node: GNNode = null

## Map of slot index → port info for event handling.
var _slot_map: Array[Dictionary] = []

## Emitted when the user commits a rename (old_id, new_id).
signal rename_requested(old_id: String, new_id: String)

## Emitted when the user clicks the help (?) button on a node.
signal help_requested(node_id: String)

## Emitted when the user clicks the eye (viewer pin) button on a node.
signal viewer_pin_requested(node_id: String)

## Emitted when the user double-clicks the body of a SubNetworkNode to dive in.
signal dive_into_requested(node_id: String)

## The inline LineEdit used during rename (null when not renaming).
var _rename_edit: LineEdit = null

## Live preview control created by the GNNode.
var _preview: Control = null

## Performance overlay label (cook time + status badge).
var _perf_label: Label = null

## Viewer pin (eye) button in the title bar.
var _viewer_btn: Button = null

## Status badge label — shows ⚠ or ✖ for warnings/errors on the title bar.
var _status_badge: Label = null

## Thumbnail height in pixels (width stretches to fit the node).
const THUMBNAIL_HEIGHT := 80


# ═══════════════════════════════════════════════════════════════════════════════
# Construction
# ═══════════════════════════════════════════════════════════════════════════════

## Builds this view from a GNNode. Call once after creation.
func setup(node: GNNode) -> void:
	gn_node = node
	name = node.id
	title = node.id
	position_offset = node.graph_position
	var _script := node.get_script()
	var _is_native := _script != null and (_script as GDScript).resource_path.contains("gn_ext_native")
	tooltip_text = "%s (%s)%s" % [node.node_type, GNFamily.get_family_name(node.family),
		" [Native]" if _is_native else ""]

	# Sub-network tooltip: show inner node count + dive-in hint
	if gn_node is SubNetworkNode and gn_node.inner_network != null:
		var inner_count: int = gn_node.inner_network.get_node_count()
		tooltip_text += "\n%d inner node(s) — double-click to dive in" % inner_count

	# Apply family color to title bar via theme override
	var family_color := GNFamily.get_color(node.family)
	var title_color := family_color
	var title_color_sel := family_color.lightened(0.25)

	# Desaturate title bar for deprecated nodes
	if node.deprecated:
		title_color = title_color.darkened(0.3)
		title_color.s *= 0.4
		title_color_sel = title_color.lightened(0.15)

	# Create StyleBoxFlat for the title bar
	var sb_title := StyleBoxFlat.new()
	sb_title.bg_color = title_color
	sb_title.corner_radius_top_left = 6
	sb_title.corner_radius_top_right = 6
	sb_title.content_margin_left = 12.0
	sb_title.content_margin_right = 12.0
	sb_title.content_margin_top = 6.0
	sb_title.content_margin_bottom = 6.0
	add_theme_stylebox_override("titlebar", sb_title)

	var sb_title_sel := sb_title.duplicate()
	sb_title_sel.bg_color = title_color_sel
	add_theme_stylebox_override("titlebar_selected", sb_title_sel)

	# Title text — white with dark outline + drop shadow for readability
	# GraphNode doesn't propagate shadow/outline overrides to its internal
	# title Label, so we find it via get_titlebar_hbox() and style it directly.
	add_theme_color_override("title_color", Color.WHITE)
	var titlebar_hbox: HBoxContainer = get_titlebar_hbox()
	if titlebar_hbox != null:
		for child in titlebar_hbox.get_children():
			if child is Label:
				child.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
				child.add_theme_constant_override("outline_size", 3)
				break

	# Panel body — dark background
	var sb_panel := StyleBoxFlat.new()
	sb_panel.bg_color = Color(0.12, 0.12, 0.14, 0.95)
	sb_panel.corner_radius_bottom_left = 4
	sb_panel.corner_radius_bottom_right = 4
	sb_panel.content_margin_left = 8.0
	sb_panel.content_margin_right = 8.0
	sb_panel.content_margin_top = 4.0
	sb_panel.content_margin_bottom = 4.0
	sb_panel.border_width_left = 1
	sb_panel.border_width_right = 1
	sb_panel.border_width_bottom = 1
	sb_panel.border_color = family_color.darkened(0.3)
	add_theme_stylebox_override("panel", sb_panel)

	var sb_panel_sel := sb_panel.duplicate()
	sb_panel_sel.border_color = family_color
	sb_panel_sel.border_width_left = 2
	sb_panel_sel.border_width_right = 2
	sb_panel_sel.border_width_bottom = 2
	add_theme_stylebox_override("panel_selected", sb_panel_sel)

	# Build port slots
	_build_slots()

	# Add live preview area — supports all node families.
	# The node decides what to show via get_preview_texture() or
	# create_preview_control() (custom rendering).
	_setup_preview()

	# Add help (?) button to the title bar
	_setup_help_button()

	# Add viewer pin (eye) button to the title bar
	_setup_viewer_button()

	# Add warning/error status badge to the title bar
	_setup_status_badge()

	# Add deprecation badge to the title bar
	if node.deprecated:
		_setup_deprecation_badge()

	# Track position changes
	position_offset_changed.connect(_on_position_changed)

	# React to dynamic port changes at runtime
	gn_node.ports_changed.connect(_on_ports_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# Port Slots
# ═══════════════════════════════════════════════════════════════════════════════

## Builds GraphNode slot rows from the GNNode's input and output ports.
## Each slot row has an optional left (input) and right (output) port.
func _build_slots() -> void:
	# Clear existing slot configs for all previous rows first
	for i in range(_slot_map.size()):
		set_slot(i, false, 0, Color.WHITE, false, 0, Color.WHITE)

	# Detach non-slot children (preview, perf overlay) so they survive the
	# wipe — they'll be re-added after the new slot rows are in place.
	var _preserved: Array[Control] = []
	if _preview != null and is_instance_valid(_preview) and _preview.get_parent() == self:
		remove_child(_preview)
		_preserved.append(_preview)
	if _perf_label != null and is_instance_valid(_perf_label) and _perf_label.get_parent() == self:
		remove_child(_perf_label)
		_preserved.append(_perf_label)

	# Remove existing slot-row children immediately (not queue_free — we need
	# them gone before adding new children so GraphNode slot indices stay correct).
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_slot_map.clear()

	# Determine how many slot rows we need (max of input/output count)
	var in_count := gn_node.input_ports.size()
	var out_count := gn_node.output_ports.size()
	var row_count := maxi(maxi(in_count, out_count), 1)

	for i in range(row_count):
		var has_left := i < in_count
		var has_right := i < out_count

		var left_name := gn_node.input_ports[i].display_name() if has_left else ""
		var right_name := gn_node.output_ports[i].display_name() if has_right else ""

		# Use an HBoxContainer so left/right labels stay flush against their edges
		var row_container := HBoxContainer.new()
		row_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var left_label := Label.new()
		left_label.text = left_name if has_left else ""
		left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_label.add_theme_font_size_override("font_size", 12)
		left_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		row_container.add_child(left_label)

		var right_label := Label.new()
		right_label.text = right_name if has_right else ""
		right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_label.add_theme_font_size_override("font_size", 12)
		right_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		row_container.add_child(right_label)

		# Fallback: if no ports at all on this row, show node type
		if not has_left and not has_right:
			left_label.text = gn_node.node_type
			left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		# Port tooltips — build combined tooltip for the row
		var port_tooltips: PackedStringArray = []
		if has_left and not gn_node.input_ports[i].description.is_empty():
			port_tooltips.append("%s: %s" % [left_name, gn_node.input_ports[i].description])
		if has_right and not gn_node.output_ports[i].description.is_empty():
			port_tooltips.append("%s: %s" % [right_name, gn_node.output_ports[i].description])
		if port_tooltips.size() > 0:
			row_container.tooltip_text = "\n".join(port_tooltips)
			row_container.mouse_filter = Control.MOUSE_FILTER_PASS

		add_child(row_container)

		# Configure the slot
		var left_color := Color.WHITE
		var right_color := Color.WHITE
		var left_type := 0
		var right_type := 0

		if has_left:
			left_color = GNFamily.get_color(gn_node.input_ports[i].family)
			left_type = gn_node.input_ports[i].family
		if has_right:
			right_color = GNFamily.get_color(gn_node.output_ports[i].family)
			right_type = gn_node.output_ports[i].family

		set_slot(i, has_left, left_type, left_color,
				has_right, right_type, right_color)

		_slot_map.append({
			"left": has_left,
			"right": has_right,
			"left_port": i if has_left else -1,
			"right_port": i if has_right else -1,
		})

	# If no ports at all (shouldn't happen), add a type label
	if row_count == 0:
		var type_label := Label.new()
		type_label.text = gn_node.node_type
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_label.add_theme_font_size_override("font_size", 12)
		add_child(type_label)

	# Re-attach preserved non-slot children after all slot rows so
	# GraphNode slot indices remain correct.
	for ctrl in _preserved:
		add_child(ctrl)


## Public entry point — rebuilds all slot rows from the current port arrays.
## Called by GNGraphEditor when ports_changed fires after stale connections are pruned.
func rebuild_slots() -> void:
	_build_slots()
	# Force GraphNode to recalculate its minimum size so it shrinks when
	# ports are removed (GraphNode caches its size otherwise).
	reset_size()


# ═══════════════════════════════════════════════════════════════════════════════
# Sync
# ═══════════════════════════════════════════════════════════════════════════════

## Called when the user drags the node in the graph editor.
func _on_position_changed() -> void:
	if gn_node:
		gn_node.graph_position = position_offset


## Updates cook status indicator (can be called each frame or on cook).
func update_status() -> void:
	if gn_node == null:
		return
	update_status_badge()


## Sets up the preview area for this node.
## Delegates to the GNNode's create_preview_control() virtual method.
func _setup_preview() -> void:
	_preview = gn_node.create_preview_control()
	if _preview != null:
		_preview.custom_minimum_size = Vector2(120, THUMBNAIL_HEIGHT)
		_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_preview)


## Adds a small "?" button to the GraphNode title bar.
## Uses GraphNode.get_titlebar_hbox() to inject into the built-in title HBox.
func _setup_help_button() -> void:
	var titlebar: HBoxContainer = get_titlebar_hbox()
	if titlebar == null:
		return

	var btn := Button.new()
	btn.text = "?"
	btn.tooltip_text = "Show node help"
	btn.custom_minimum_size = Vector2(24, 24)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 12)
	# Flat style so it doesn't clash with the title bar
	btn.flat = true
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.7))
	# Dark outline for readability on colored title bars
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	btn.add_theme_constant_override("outline_size", 3)
	btn.pressed.connect(func(): help_requested.emit(gn_node.id))
	titlebar.add_child(btn)


## Adds a small eye button to the GraphNode title bar for pinning to the viewer.
func _setup_viewer_button() -> void:
	var titlebar: HBoxContainer = get_titlebar_hbox()
	if titlebar == null:
		return

	_viewer_btn = Button.new()
	_viewer_btn.text = "👁"
	_viewer_btn.tooltip_text = "Pin to viewer"
	_viewer_btn.custom_minimum_size = Vector2(24, 24)
	_viewer_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_viewer_btn.add_theme_font_size_override("font_size", 12)
	_viewer_btn.flat = true
	_viewer_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_viewer_btn.add_theme_color_override("font_hover_color", Color(0.3, 1.0, 0.9))
	_viewer_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_viewer_btn.add_theme_constant_override("outline_size", 3)
	_viewer_btn.pressed.connect(func(): viewer_pin_requested.emit(gn_node.id))
	titlebar.add_child(_viewer_btn)


## Sets the viewer pin button to active (highlighted) or inactive.
func set_viewer_active(active: bool) -> void:
	if _viewer_btn == null:
		return
	if active:
		_viewer_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.9))
		_viewer_btn.text = "�"
		_viewer_btn.tooltip_text = "Pinned to viewer (click to unpin)"
	else:
		_viewer_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_viewer_btn.text = "👁"
		_viewer_btn.tooltip_text = "Pin to viewer"


## Updates the preview from the GNNode's current state.
func update_preview() -> void:
	if _preview != null and _preview.visible and gn_node != null:
		gn_node.update_preview_control(_preview)


## Shows the preview control (if one exists).
func show_preview() -> void:
	if _preview != null:
		_preview.show()
		reset_size()


## Hides the preview control.
func hide_preview() -> void:
	if _preview != null:
		_preview.hide()
		reset_size()


## Updates the performance overlay with the latest cook stats.
func update_perf_overlay() -> void:
	if _perf_label == null or not _perf_label.visible or gn_node == null:
		return

	# Inactive nodes show a dimmed "zzz" indicator
	if not gn_node.is_active:
		_perf_label.text = "zzz"
		_perf_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.6))
		return

	var status_icon := "✓" if gn_node.cook_valid else "✗"
	var cook_ms := gn_node.cook_time_ms
	# Color-code: green < 1ms, yellow < 5ms, red >= 5ms
	var color: Color
	if cook_ms < 1.0:
		color = Color(0.4, 1.0, 0.4)
	elif cook_ms < 5.0:
		color = Color(1.0, 0.9, 0.3)
	else:
		color = Color(1.0, 0.35, 0.3)
	_perf_label.text = "%s %.2fms" % [status_icon, cook_ms]
	_perf_label.add_theme_color_override("font_color", color)


## Shows the performance overlay label.
func show_perf_overlay() -> void:
	if _perf_label == null:
		_setup_perf_overlay()
	_perf_label.show()
	reset_size()


## Hides the performance overlay label.
func hide_perf_overlay() -> void:
	if _perf_label != null:
		_perf_label.hide()
		reset_size()


## Creates the perf overlay label (called lazily on first show).
func _setup_perf_overlay() -> void:
	_perf_label = Label.new()
	_perf_label.text = "— 0.00ms"
	_perf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_perf_label.add_theme_font_size_override("font_size", 11)
	_perf_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_perf_label.custom_minimum_size = Vector2(80, 16)
	_perf_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_perf_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_perf_label)


## Creates the status badge label in the title bar (hidden by default).
func _setup_status_badge() -> void:
	var titlebar: HBoxContainer = get_titlebar_hbox()
	if titlebar == null:
		return
	_status_badge = Label.new()
	_status_badge.text = ""
	_status_badge.visible = false
	_status_badge.add_theme_font_size_override("font_size", 14)
	_status_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_status_badge.add_theme_constant_override("outline_size", 3)
	_status_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status_badge.mouse_filter = Control.MOUSE_FILTER_PASS
	titlebar.add_child(_status_badge)


## Updates the status badge based on the node's current warning/error strings.
func update_status_badge() -> void:
	if gn_node == null or _status_badge == null:
		return
	if not gn_node.node_error.is_empty():
		_status_badge.text = "\u2716"  # ✖
		_status_badge.tooltip_text = gn_node.node_error
		_status_badge.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_status_badge.visible = true
	elif not gn_node.node_warning.is_empty():
		_status_badge.text = "\u26A0"  # ⚠
		_status_badge.tooltip_text = gn_node.node_warning
		_status_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		_status_badge.visible = true
	else:
		_status_badge.visible = false
		_status_badge.tooltip_text = ""


## Creates a permanent deprecation badge (⊘) in the title bar.
func _setup_deprecation_badge() -> void:
	var titlebar: HBoxContainer = get_titlebar_hbox()
	if titlebar == null:
		return
	var badge := Label.new()
	badge.text = "\u2298"  # ⊘
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2, 0.9))
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	badge.add_theme_constant_override("outline_size", 3)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	var tip := "DEPRECATED"
	if not gn_node.deprecation_message.is_empty():
		tip += " — " + gn_node.deprecation_message
	badge.tooltip_text = tip
	titlebar.add_child(badge)


## Handler for GNNode.ports_changed — triggers a slot rebuild.
## Actual connection pruning is handled by GNGraphEditor before this fires.
func _on_ports_changed(_node_id: String) -> void:
	rebuild_slots()


# ═══════════════════════════════════════════════════════════════════════════════
# Bypass & Lock Visual State
# ═══════════════════════════════════════════════════════════════════════════════

## Updates title and visual indicators to reflect bypass/lock state.
func update_bypass_lock_visuals() -> void:
	if gn_node == null:
		return

	# Title text: prepend state indicators
	var base_title := gn_node.id
	if gn_node.bypass and gn_node.locked:
		title = "⏩🔒 " + base_title
	elif gn_node.bypass:
		title = "⏩ " + base_title
	elif gn_node.locked:
		title = "🔒 " + base_title
	else:
		title = base_title

	# Dim the node when bypassed
	self_modulate = Color(0.5, 0.5, 0.5, 0.7) if gn_node.bypass else Color.WHITE

	reset_size()


# ═══════════════════════════════════════════════════════════════════════════════
# Inline Rename
# ═══════════════════════════════════════════════════════════════════════════════

## Detect double-click on the title bar to start renaming,
## or on the body to dive into a sub-network.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
		# Title bar area — start rename
		if event.position.y <= 30.0:
			_start_rename()
			accept_event()
		# Body area — dive into sub-network (if applicable)
		elif gn_node is SubNetworkNode:
			dive_into_requested.emit(gn_node.id)
			accept_event()


## Opens an inline LineEdit over the title bar for renaming.
func _start_rename() -> void:
	if _rename_edit != null:
		return  # Already renaming
	if gn_node == null:
		return

	_rename_edit = LineEdit.new()
	_rename_edit.text = gn_node.id
	_rename_edit.select_all()
	_rename_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rename_edit.add_theme_font_size_override("font_size", 14)

	# Position over the title bar
	_rename_edit.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_rename_edit.offset_top = 2.0
	_rename_edit.offset_bottom = 28.0
	_rename_edit.offset_left = 4.0
	_rename_edit.offset_right = -4.0

	add_child(_rename_edit)
	_rename_edit.grab_focus()

	_rename_edit.text_submitted.connect(_on_rename_submitted)
	_rename_edit.focus_exited.connect(_on_rename_focus_lost)


## Commits the rename when the user presses Enter.
func _on_rename_submitted(new_text: String) -> void:
	_finish_rename(new_text.strip_edges())


## Commits the rename when the LineEdit loses focus.
func _on_rename_focus_lost() -> void:
	if _rename_edit != null:
		_finish_rename(_rename_edit.text.strip_edges())


## Validates and emits the rename request, then removes the LineEdit.
func _finish_rename(new_id: String) -> void:
	if _rename_edit == null:
		return

	var old_id := gn_node.id

	# Clean up the LineEdit first
	var edit := _rename_edit
	_rename_edit = null
	edit.text_submitted.disconnect(_on_rename_submitted)
	if edit.focus_exited.is_connected(_on_rename_focus_lost):
		edit.focus_exited.disconnect(_on_rename_focus_lost)
	remove_child(edit)
	edit.queue_free()
	reset_size()

	# Only emit if the name actually changed and isn't empty
	if new_id.is_empty() or new_id == old_id:
		return

	rename_requested.emit(old_id, new_id)


## Updates the view after a successful rename (called by GNGraphEditor).
func apply_rename(old_id: String, new_id: String) -> void:
	name = new_id
	tooltip_text = "%s (%s)" % [gn_node.node_type, GNFamily.get_family_name(gn_node.family)]
	# Rebuild title with bypass/lock indicators
	update_bypass_lock_visuals()
