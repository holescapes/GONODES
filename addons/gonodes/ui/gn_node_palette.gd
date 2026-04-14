class_name GNNodePalette
extends PopupPanel
## Popup palette that lets users pick an operator type to spawn.
## Displays available operators grouped by family (TOP, CHOP, etc.)
## Triggered by Tab key or right-click in the graph editor.

## Emitted when the user selects a node type.
signal node_type_selected(operator_type: String)

## Search/filter input.
var _search_edit: LineEdit = null

## Scrollable row of family filter pills.
var _pill_container: HBoxContainer = null

## Currently selected family filter — -1 means "All", -2 means "Custom only".
var _active_family_filter: int = -1

const _FILTER_ALL := -1
const _FILTER_CUSTOM := -2

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

	# Family filter pill row
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.custom_minimum_size.y = 24
	vbox.add_child(scroll)

	_pill_container = HBoxContainer.new()
	_pill_container.add_theme_constant_override("separation", 3)
	scroll.add_child(_pill_container)
	# Pills are built lazily on first popup — families aren't registered yet at _ready time.

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
	_ensure_pills()
	position = Vector2i(global_pos)
	popup()
	_search_edit.text = ""
	_search_edit.grab_focus()
	_populate_tree("")


## Opens the palette filtered to only show operators in [param allowed].
## Used when the user drops a connection on empty space — only compatible nodes shown.
func popup_at_filtered(global_pos: Vector2, allowed: PackedStringArray) -> void:
	_allowed_operators = allowed
	_ensure_pills()
	position = Vector2i(global_pos)
	popup()
	_search_edit.text = ""
	_search_edit.grab_focus()
	_populate_tree("")


## Builds pills from the current registry, then resets the filter to "All".
func _ensure_pills() -> void:
	_build_family_pills()
	_reset_pills()


## Resets the pill filter back to "All" without triggering a tree rebuild.
func _reset_pills() -> void:
	_active_family_filter = _FILTER_ALL
	for child in _pill_container.get_children():
		var fid: int = child.get_meta("family_id")
		var is_all := (fid == _FILTER_ALL)
		child.set_pressed_no_signal(is_all)
		var color: Color
		if fid == _FILTER_ALL:
			color = Color(0.7, 0.7, 0.7)
		elif fid == _FILTER_CUSTOM:
			color = Color(0.9, 0.75, 0.3)
		else:
			color = GNFamily.get_color(fid)
		_style_pill(child, color, is_all)


# ═══════════════════════════════════════════════════════════════════════════════
# Family Pills
# ═══════════════════════════════════════════════════════════════════════════════

## Builds the family filter pill/chip row from the dynamic family registry.
func _build_family_pills() -> void:
	for child in _pill_container.get_children():
		child.queue_free()

	# "All" pill
	var all_btn := Button.new()
	all_btn.text = "All"
	all_btn.toggle_mode = true
	all_btn.button_pressed = true
	all_btn.flat = true
	all_btn.custom_minimum_size = Vector2(32, 22)
	all_btn.add_theme_font_size_override("font_size", 11)
	all_btn.set_meta("family_id", -1)
	all_btn.toggled.connect(_on_pill_toggled.bind(-1))
	_pill_container.add_child(all_btn)
	_style_pill(all_btn, Color(0.7, 0.7, 0.7), true)

	# "Custom" pill — shows only .gnasset custom operators
	var custom_btn := Button.new()
	custom_btn.text = "Custom"
	custom_btn.toggle_mode = true
	custom_btn.button_pressed = false
	custom_btn.flat = true
	custom_btn.custom_minimum_size = Vector2(32, 22)
	custom_btn.add_theme_font_size_override("font_size", 11)
	custom_btn.set_meta("family_id", _FILTER_CUSTOM)
	custom_btn.toggled.connect(_on_pill_toggled.bind(_FILTER_CUSTOM))
	_pill_container.add_child(custom_btn)
	_style_pill(custom_btn, Color(0.9, 0.75, 0.3), false)

	# One pill per registered family (sorted: core 0-11, then extensions 1000+)
	var result: Array = GNFamily.get_all_families()
	var ids: Array = result[0]
	var names: PackedStringArray = result[1]
	for i in ids.size():
		var fam_id: int = ids[i]
		var fam_name: String = names[i]
		var fam_color: Color = GNFamily.get_color(fam_id)
		var btn := Button.new()
		btn.text = fam_name
		btn.toggle_mode = true
		btn.button_pressed = false
		btn.flat = true
		btn.custom_minimum_size = Vector2(32, 22)
		btn.add_theme_font_size_override("font_size", 11)
		btn.set_meta("family_id", fam_id)
		btn.toggled.connect(_on_pill_toggled.bind(fam_id))
		_pill_container.add_child(btn)
		_style_pill(btn, fam_color, false)


## Applies colored StyleBoxFlat to a pill button.
func _style_pill(btn: Button, color: Color, active: bool) -> void:
	var bg := StyleBoxFlat.new()
	bg.corner_radius_top_left = 10
	bg.corner_radius_top_right = 10
	bg.corner_radius_bottom_left = 10
	bg.corner_radius_bottom_right = 10
	bg.content_margin_left = 6
	bg.content_margin_right = 6
	bg.content_margin_top = 2
	bg.content_margin_bottom = 2

	if active:
		bg.bg_color = color.lerp(Color.WHITE, 0.15)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	else:
		bg.bg_color = color.darkened(0.5)
		bg.bg_color.a = 0.45
		btn.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.3))
		btn.add_theme_color_override("font_pressed_color", color.lerp(Color.WHITE, 0.3))

	# Hover gets a subtle brighten on top of the current state.
	var hover := bg.duplicate()
	hover.bg_color = hover.bg_color.lightened(0.15)

	btn.add_theme_stylebox_override("normal", bg)
	btn.add_theme_stylebox_override("pressed", bg)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("hover_pressed", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Handles a pill toggle — single-select radio behavior.
func _on_pill_toggled(pressed: bool, family_id: int) -> void:
	if not pressed:
		# Don't allow deselecting the already-active pill (radio behavior)
		for child in _pill_container.get_children():
			if child.get_meta("family_id") == family_id:
				child.set_pressed_no_signal(true)
				return
		return

	_active_family_filter = family_id

	# Update visuals: activate the pressed pill, deactivate the rest
	for child in _pill_container.get_children():
		var fid: int = child.get_meta("family_id")
		var is_active := (fid == family_id)
		child.set_pressed_no_signal(is_active)
		var color: Color
		if fid == _FILTER_ALL:
			color = Color(0.7, 0.7, 0.7)
		elif fid == _FILTER_CUSTOM:
			color = Color(0.9, 0.75, 0.3)
		else:
			color = GNFamily.get_color(fid)
		_style_pill(child, color, is_active)

	_populate_tree(_search_edit.text)


# ═══════════════════════════════════════════════════════════════════════════════
# Tree Population
# ═══════════════════════════════════════════════════════════════════════════════

## Builds or rebuilds the tree, optionally filtering by search text.
## Operators with a non-empty section get grouped under a sub-heading within
## their family (e.g. TOP → Shadertoy → ShadertoyTOP).
## Custom assets get a dedicated "Custom" top-level section with
## Custom → Family → Extension/User → Asset hierarchy.
func _populate_tree(filter: String) -> void:
	_tree.clear()
	var root := _tree.create_item()
	var reg := GNExtensionRegistry.instance()
	var registry_sectioned := reg.get_operator_registry_sectioned()
	var custom_registry := reg.get_custom_asset_registry()
	var filter_lower := filter.to_lower()

	# ── Built-in operators (excludes custom assets) ────────────────────
	var _show_builtin := (_active_family_filter != _FILTER_CUSTOM)
	for family_enum: int in GNFamily.FAMILY_NAMES:
		if not _show_builtin:
			break
		var family_name: String = GNFamily.FAMILY_NAMES[family_enum]
		if not registry_sectioned.has(family_name):
			continue
		# Family pill filter: skip families that don't match the active pill
		if _active_family_filter >= 0 and family_enum != _active_family_filter:
			continue

		var sections: Dictionary = registry_sectioned[family_name]
		var family_color: Color = GNFamily.get_color(family_enum)

		# Pre-filter: skip custom_asset ops (they go in the Custom section)
		var any_visible := false
		for sec_name in sections:
			for op_name in sections[sec_name]:
				var entry: GNExtensionRegistry.OperatorEntry = reg.get_entry(op_name)
				if entry != null and entry.is_custom_asset:
					continue
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
				var entry: GNExtensionRegistry.OperatorEntry = reg.get_entry(op_name)
				if entry != null and entry.is_custom_asset:
					continue  # Skip custom assets — they go in Custom section
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
				_add_operator_item(parent_item, op_name, reg)

	# ── Custom Assets — dedicated top-level section ────────────────────
	var custom_any_visible := false
	for fam_name in custom_registry:
		# Family pill filter applies to custom assets too
		if _active_family_filter >= 0:
			var fam_id_pre: int = GNFamily.string_to_type(fam_name)
			if fam_id_pre != _active_family_filter:
				continue
		for sec_name in custom_registry[fam_name]:
			for op_name in custom_registry[fam_name][sec_name]:
				if not _allowed_operators.is_empty() and not _allowed_operators.has(op_name):
					continue
				if filter_lower.is_empty() or op_name.to_lower().contains(filter_lower):
					custom_any_visible = true
					break
			if custom_any_visible:
				break
		if custom_any_visible:
			break

	if custom_any_visible:
		var custom_root := _tree.create_item(root)
		custom_root.set_text(0, "Custom")
		custom_root.set_selectable(0, false)
		custom_root.set_custom_color(0, Color(0.9, 0.75, 0.3))

		# Sort families alphabetically within custom
		var custom_fam_keys: Array = custom_registry.keys()
		custom_fam_keys.sort()

		for fam_name in custom_fam_keys:
			# Family pill filter: skip non-matching families in custom section too
			if _active_family_filter >= 0:
				var fam_id_check: int = GNFamily.string_to_type(fam_name)
				if fam_id_check != _active_family_filter:
					continue
			var fam_sections: Dictionary = custom_registry[fam_name]
			var fam_color: Color = GNFamily.get_color(GNFamily.string_to_type(fam_name))

			# Check if any ops in this family pass filter
			var fam_visible := false
			for sec_name in fam_sections:
				for op_name in fam_sections[sec_name]:
					if not _allowed_operators.is_empty() and not _allowed_operators.has(op_name):
						continue
					if filter_lower.is_empty() or op_name.to_lower().contains(filter_lower):
						fam_visible = true
						break
				if fam_visible:
					break
			if not fam_visible:
				continue

			# Custom → Family
			var fam_item := _tree.create_item(custom_root)
			fam_item.set_text(0, fam_name)
			fam_item.set_selectable(0, false)
			fam_item.set_custom_color(0, fam_color)

			# Sort sections: alphabetical
			var sec_keys: Array = fam_sections.keys()
			sec_keys.sort()

			for sec_name in sec_keys:
				var ops: Array = fam_sections[sec_name]
				var filtered_ops: Array[String] = []
				for op_name in ops:
					if not _allowed_operators.is_empty() and not _allowed_operators.has(op_name):
						continue
					if filter_lower.is_empty() or op_name.to_lower().contains(filter_lower):
						filtered_ops.append(op_name)

				if filtered_ops.is_empty():
					continue

				# Custom → Family → Extension/User
				var parent_item: TreeItem = fam_item
				if sec_keys.size() > 1 or sec_name != "User":
					var sec_item := _tree.create_item(fam_item)
					sec_item.set_text(0, sec_name)
					sec_item.set_selectable(0, false)
					sec_item.set_custom_color(0, fam_color.lerp(Color.WHITE, 0.35))
					parent_item = sec_item

				for op_name in filtered_ops:
					_add_operator_item(parent_item, op_name, reg)

	# Auto-select first selectable item if filtering
	if not filter_lower.is_empty():
		_select_first_leaf(root)


## Adds a single operator item to the tree under [param parent_item].
func _add_operator_item(parent_item: TreeItem, op_name: String,
		reg: GNExtensionRegistry) -> void:
	var op_item := _tree.create_item(parent_item)
	var entry: GNExtensionRegistry.OperatorEntry = reg.get_entry(op_name)
	if entry != null and entry.deprecated:
		op_item.set_text(0, "\u29b8 " + op_name + "  (deprecated)")
		op_item.set_custom_color(0, Color(0.5, 0.5, 0.5))
	elif entry != null and entry.is_custom_asset:
		op_item.set_text(0, op_name)
		op_item.set_custom_color(0, Color(0.9, 0.85, 0.6))
	else:
		op_item.set_text(0, op_name)
	op_item.set_metadata(0, op_name)
	var desc := _get_operator_description(op_name)
	if entry != null and entry.deprecated and not entry.deprecation_message.is_empty():
		desc = "\u26a0 DEPRECATED: " + entry.deprecation_message + ("\n" + desc if not desc.is_empty() else "")
	if entry != null and entry.is_custom_asset and entry.asset_read_only:
		desc = ("[extension asset] " if desc.is_empty() else desc + "\n") + "(read-only — from extension)"
	if not desc.is_empty():
		op_item.set_tooltip_text(0, desc)


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
