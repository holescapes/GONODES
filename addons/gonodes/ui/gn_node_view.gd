class_name GNNodeView
extends GraphNode
## Visual representation of a single GNNode operator in the graph editor.
## Shows family-colored title bar, typed port slots, and the node name.
## One GNNodeView per GNNode in the network.

## The GNNode this view represents.
var gn_node: GNNode = null

## Map of slot index → port info for event handling.
var _slot_map: Array[Dictionary] = []


# ═══════════════════════════════════════════════════════════════════════════════
# Construction
# ═══════════════════════════════════════════════════════════════════════════════

## Builds this view from a GNNode. Call once after creation.
func setup(node: GNNode) -> void:
	gn_node = node
	name = node.id
	title = "%s  [%s]" % [node.id, GNFamily.get_family_name(node.family)]
	position_offset = node.graph_position
	tooltip_text = "%s (%s)" % [node.node_type, GNFamily.get_family_name(node.family)]

	# Apply family color to title bar via theme override
	var family_color := GNFamily.get_color(node.family)
	var title_color := family_color
	var title_color_sel := family_color.lightened(0.25)

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

	# Track position changes
	position_offset_changed.connect(_on_position_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# Port Slots
# ═══════════════════════════════════════════════════════════════════════════════

## Builds GraphNode slot rows from the GNNode's input and output ports.
## Each slot row has an optional left (input) and right (output) port.
func _build_slots() -> void:
	# Clear any existing children
	for child in get_children():
		child.queue_free()
	_slot_map.clear()

	# Determine how many slot rows we need (max of input/output count)
	var in_count := gn_node.input_ports.size()
	var out_count := gn_node.output_ports.size()
	var row_count := maxi(maxi(in_count, out_count), 1)

	for i in range(row_count):
		var has_left := i < in_count
		var has_right := i < out_count

		# Create a label for this slot row
		var row_label := Label.new()
		var left_name := gn_node.input_ports[i].port_name if has_left else ""
		var right_name := gn_node.output_ports[i].port_name if has_right else ""

		if has_left and has_right:
			row_label.text = "%s      %s" % [left_name, right_name]
			row_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		elif has_left:
			row_label.text = left_name
			row_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		elif has_right:
			row_label.text = right_name
			row_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		else:
			row_label.text = gn_node.node_type
			row_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		row_label.add_theme_font_size_override("font_size", 12)
		row_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		add_child(row_label)

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
	# Could add visual feedback (glow, error badge) here in the future
	pass
