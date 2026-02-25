class_name GNNodePalette
extends PopupPanel
## Popup palette that lets users pick an operator type to spawn.
## Displays available operators grouped by family (TOP, CHOP, etc.)
## Triggered by Tab key or right-click in the graph editor.

## Emitted when the user selects a node type.
signal node_type_selected(operator_type: String)

## Search/filter input.
var _search_edit: LineEdit = null

## Tree that displays operators grouped by family.
var _tree: Tree = null


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Panel sizing
	min_size = Vector2(240, 340)
	size = Vector2(240, 340)
	transparent = false
	popup_window = true

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Search bar
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search operators…"
	_search_edit.clear_button_enabled = true
	_search_edit.text_changed.connect(_on_search_changed)
	vbox.add_child(_search_edit)

	# Tree
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_activated.connect(_on_item_activated)
	vbox.add_child(_tree)

	# Close when losing focus
	popup_hide.connect(_on_popup_hide)

	_populate_tree("")


## Opens the palette popup at the given global position.
func popup_at(global_pos: Vector2) -> void:
	position = Vector2i(global_pos)
	popup()
	_search_edit.text = ""
	_search_edit.grab_focus()
	_populate_tree("")


# ═══════════════════════════════════════════════════════════════════════════════
# Tree Population
# ═══════════════════════════════════════════════════════════════════════════════

## Builds or rebuilds the tree, optionally filtering by search text.
func _populate_tree(filter: String) -> void:
	_tree.clear()
	var root := _tree.create_item()
	var registry := GNGraphEditor.get_operator_registry()
	var filter_lower := filter.to_lower()

	# Family display order
	var families := ["TOP", "CHOP", "SOP", "POP", "DAT", "MAT", "COMP"]

	for family_name in families:
		if not registry.has(family_name):
			continue

		var ops: Array = registry[family_name]
		var filtered_ops: Array[String] = []

		for op_name in ops:
			if filter_lower.is_empty() or op_name.to_lower().contains(filter_lower):
				filtered_ops.append(op_name)

		if filtered_ops.is_empty():
			continue

		# Create family group
		var family_item := _tree.create_item(root)
		family_item.set_text(0, family_name)
		family_item.set_selectable(0, false)

		# Color the family header
		var family_enum := _family_name_to_enum(family_name)
		if family_enum >= 0:
			family_item.set_custom_color(0, GNFamily.get_color(family_enum))

		# Add operators under the family
		for op_name in filtered_ops:
			var op_item := _tree.create_item(family_item)
			op_item.set_text(0, op_name)
			op_item.set_metadata(0, op_name)
			# Show node description as tooltip if available
			var desc := _get_operator_description(op_name)
			if not desc.is_empty():
				op_item.set_tooltip_text(0, desc)

	# Auto-select first selectable item if filtering
	if not filter_lower.is_empty():
		_select_first_leaf(root)


## Selects the first selectable leaf item in the tree (for keyboard navigation).
## Returns true if a leaf was selected.
func _select_first_leaf(parent: TreeItem) -> bool:
	var child := parent.get_first_child()
	while child:
		if child.is_selectable(0):
			child.select(0)
			_tree.scroll_to_item(child)
			return true
		# Recurse into groups
		if _select_first_leaf(child):
			return true
		child = child.get_next()
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# Event Handlers
# ═══════════════════════════════════════════════════════════════════════════════

## User types in the search bar.
func _on_search_changed(new_text: String) -> void:
	_populate_tree(new_text)


## User double-clicks or presses Enter on an operator item.
func _on_item_activated() -> void:
	var selected := _tree.get_selected()
	if selected == null:
		return

	var op_name = selected.get_metadata(0)
	if op_name == null or str(op_name).is_empty():
		return

	node_type_selected.emit(str(op_name))
	hide()


## Called when popup is hidden.
func _on_popup_hide() -> void:
	_search_edit.text = ""


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			hide()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_item_activated()
			get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Converts a family name string to the GNFamily.Type enum value.
static func _family_name_to_enum(family_name: String) -> int:
	match family_name:
		"TOP": return GNFamily.Type.TOP
		"CHOP": return GNFamily.Type.CHOP
		"SOP": return GNFamily.Type.SOP
		"POP": return GNFamily.Type.POP
		"DAT": return GNFamily.Type.DAT
		"MAT": return GNFamily.Type.MAT
		"COMP": return GNFamily.Type.COMP
		_: return -1


## Returns a short description for an operator class name (for palette tooltips).
## Delegates to GNExtensionRegistry so extensions can provide their own descriptions.
static func _get_operator_description(op_name: String) -> String:
	return GNExtensionRegistry.instance().get_description(op_name)
