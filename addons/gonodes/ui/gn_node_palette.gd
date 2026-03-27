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

## When non-empty, only these operator names are shown (for connection-drop filtering).
var _allowed_operators: PackedStringArray = []


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
	_search_edit.gui_input.connect(_on_search_gui_input)
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
	_allowed_operators = []
	position = Vector2i(global_pos)
	popup()
	_search_edit.text = ""
	_search_edit.grab_focus()
	_populate_tree("")


## Opens the palette filtered to only show operators in [param allowed].
## Used when the user drops a connection on empty space — only compatible nodes shown.
func popup_at_filtered(global_pos: Vector2, allowed: PackedStringArray) -> void:
	_allowed_operators = allowed
	position = Vector2i(global_pos)
	popup()
	_search_edit.text = ""
	_search_edit.grab_focus()
	_populate_tree("")


# ═══════════════════════════════════════════════════════════════════════════════
# Tree Population
# ═══════════════════════════════════════════════════════════════════════════════

## Builds or rebuilds the tree, optionally filtering by search text.
## Operators with a non-empty section get grouped under a sub-heading within
## their family (e.g. TOP → Shadertoy → ShadertoyTOP).
func _populate_tree(filter: String) -> void:
	_tree.clear()
	var root := _tree.create_item()
	var reg := GNExtensionRegistry.instance()
	var registry_sectioned := reg.get_operator_registry_sectioned()
	var filter_lower := filter.to_lower()

	# Iterate families in enum order (driven by GNFamily.FAMILY_NAMES).
	# No hardcoded list — new families are picked up automatically.
	for family_enum: int in GNFamily.FAMILY_NAMES:
		var family_name: String = GNFamily.FAMILY_NAMES[family_enum]
		if not registry_sectioned.has(family_name):
			continue

		var sections: Dictionary = registry_sectioned[family_name]
		var family_color: Color = GNFamily.get_color(family_enum)

		# Pre-filter all ops across all sections to decide if the family header
		# should appear at all.
		var any_visible := false
		for sec_name in sections:
			for op_name in sections[sec_name]:
				if not _allowed_operators.is_empty() and not _allowed_operators.has(op_name):
					continue
				if filter_lower.is_empty() or op_name.to_lower().contains(filter_lower):
					any_visible = true
					break
			if any_visible:
				break
		if not any_visible:
			continue

		# Create family group
		var family_item := _tree.create_item(root)
		family_item.set_text(0, family_name)
		family_item.set_selectable(0, false)
		family_item.set_custom_color(0, family_color)

		# Sort section keys: unsectioned ("") first, then alphabetical
		var sec_keys: Array = sections.keys()
		sec_keys.sort()
		if sec_keys.has(""):
			sec_keys.erase("")
			sec_keys.insert(0, "")

		for sec_name in sec_keys:
			var ops: Array = sections[sec_name]
			var filtered_ops: Array[String] = []

			for op_name in ops:
				if not _allowed_operators.is_empty() and not _allowed_operators.has(op_name):
					continue
				if filter_lower.is_empty() or op_name.to_lower().contains(filter_lower):
					filtered_ops.append(op_name)

			if filtered_ops.is_empty():
				continue

			# Determine the parent for operator items
			var parent_item: TreeItem = family_item
			if not sec_name.is_empty():
				# Create a section sub-heading under the family
				var sec_item := _tree.create_item(family_item)
				sec_item.set_text(0, sec_name)
				sec_item.set_selectable(0, false)
				# Dim the section header slightly relative to the family color
				sec_item.set_custom_color(0, family_color.lerp(Color.WHITE, 0.35))
				parent_item = sec_item

			# Add operators under the parent (family or section)
			for op_name in filtered_ops:
				var op_item := _tree.create_item(parent_item)
				op_item.set_text(0, op_name)
				op_item.set_metadata(0, op_name)
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


## Intercepts Up/Down/Enter in the search LineEdit for tree navigation.
func _on_search_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_DOWN:
			_select_next_leaf()
			_search_edit.accept_event()
		KEY_UP:
			_select_prev_leaf()
			_search_edit.accept_event()
		KEY_ENTER, KEY_KP_ENTER:
			_on_item_activated()
			_search_edit.accept_event()


## Selects the next selectable item below the current selection.
func _select_next_leaf() -> void:
	var selected := _tree.get_selected()
	if selected == null:
		_select_first_leaf(_tree.get_root())
		return
	var item := selected.get_next_visible()
	while item:
		if item.is_selectable(0):
			item.select(0)
			_tree.scroll_to_item(item)
			return
		item = item.get_next_visible()


## Selects the previous selectable item above the current selection.
func _select_prev_leaf() -> void:
	var selected := _tree.get_selected()
	if selected == null:
		_select_first_leaf(_tree.get_root())
		return
	var item := selected.get_prev_visible()
	while item:
		if item.is_selectable(0):
			item.select(0)
			_tree.scroll_to_item(item)
			return
		item = item.get_prev_visible()


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
	_allowed_operators = []


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

## Returns a short description for an operator class name (for palette tooltips).
## Delegates to GNExtensionRegistry so extensions can provide their own descriptions.
static func _get_operator_description(op_name: String) -> String:
	return GNExtensionRegistry.instance().get_description(op_name)
