class_name GNGraphSearch
extends RefCounted
## Manages the Ctrl+F node search overlay for GNGraphEditor.
## Handles search bar UI, matching, navigation, and dimming.

var _graph: GraphEdit = null
var _node_views: Dictionary  # Reference to GNGraphEditor._node_views

var _search_bar: PanelContainer = null
var _search_edit: LineEdit = null
var _search_label: Label = null
var _search_matches: Array[String] = []
var _search_index: int = -1
var _search_dimmed: bool = false

var _deselect_all_cb: Callable
var _scroll_to_node_cb: Callable


func setup(graph: GraphEdit, node_views: Dictionary,
		deselect_all: Callable, scroll_to_node: Callable) -> void:
	_graph = graph
	_node_views = node_views
	_deselect_all_cb = deselect_all
	_scroll_to_node_cb = scroll_to_node
	_build_search_bar()


func _build_search_bar() -> void:
	_search_bar = PanelContainer.new()
	_search_bar.name = "SearchBar"
	_search_bar.visible = false
	_search_bar.z_index = 4096
	_search_bar.z_as_relative = false
	_search_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_search_bar.custom_minimum_size = Vector2(380, 0)
	_search_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_search_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_search_bar.position = Vector2(-190, 8)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	style.border_color = Color(0.4, 0.6, 1.0, 0.6)
	style.set_border_width_all(1)
	_search_bar.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_search_bar.add_child(hbox)

	var icon := Label.new()
	icon.text = "🔍"
	icon.add_theme_font_size_override("font_size", 14)
	hbox.add_child(icon)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search nodes…"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.clear_button_enabled = true
	_search_edit.text_changed.connect(_on_search_text_changed)
	_search_edit.gui_input.connect(_on_search_edit_input)
	hbox.add_child(_search_edit)

	_search_label = Label.new()
	_search_label.text = ""
	_search_label.add_theme_font_size_override("font_size", 12)
	_search_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	_search_label.custom_minimum_size = Vector2(80, 0)
	_search_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(_search_label)

	var prev_btn := Button.new()
	prev_btn.text = "▲"
	prev_btn.flat = true
	prev_btn.tooltip_text = "Previous match (Shift+Enter)"
	prev_btn.custom_minimum_size = Vector2(24, 24)
	prev_btn.pressed.connect(_navigate_search.bind(-1))
	hbox.add_child(prev_btn)

	var next_btn := Button.new()
	next_btn.text = "▼"
	next_btn.flat = true
	next_btn.tooltip_text = "Next match (Enter)"
	next_btn.custom_minimum_size = Vector2(24, 24)
	next_btn.pressed.connect(_navigate_search.bind(1))
	hbox.add_child(next_btn)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.pressed.connect(close_search)
	hbox.add_child(close_btn)

	_graph.add_child(_search_bar)


func is_search_open() -> bool:
	return _search_bar != null and _search_bar.visible


func open_search() -> void:
	if _search_bar == null:
		return
	_search_bar.visible = true
	_search_edit.text = ""
	_search_matches.clear()
	_search_index = -1
	_search_label.text = ""
	_search_edit.grab_focus()


func close_search() -> void:
	if _search_bar == null:
		return
	_search_bar.visible = false
	_search_edit.release_focus()
	_restore_search_modulation()
	_search_matches.clear()
	_search_index = -1


func _on_search_text_changed(query: String) -> void:
	_search_matches.clear()
	_search_index = -1

	if query.is_empty():
		_restore_search_modulation()
		_search_label.text = ""
		return

	var q := query.to_lower()
	for node_id in _node_views:
		var view: GNNodeView = _node_views[node_id]
		var id_lower: String = str(node_id).to_lower()
		var type_lower: String = view.gn_node.node_type.to_lower()
		if id_lower.contains(q) or type_lower.contains(q):
			_search_matches.append(node_id)

	_search_matches.sort()
	_apply_search_modulation()

	if _search_matches.is_empty():
		_search_label.text = "No matches"
	else:
		_search_index = 0
		_search_label.text = "1 of %d" % _search_matches.size()
		_navigate_to_current_match()


func _on_search_edit_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				if event.shift_pressed:
					_navigate_search(-1)
				else:
					_navigate_search(1)
				_search_edit.accept_event()
			KEY_ESCAPE:
				close_search()
				_search_edit.accept_event()


func _navigate_search(direction: int) -> void:
	if _search_matches.is_empty():
		return
	_search_index = (_search_index + direction + _search_matches.size()) % _search_matches.size()
	_search_label.text = "%d of %d" % [_search_index + 1, _search_matches.size()]
	_navigate_to_current_match()


func _navigate_to_current_match() -> void:
	if _search_index < 0 or _search_index >= _search_matches.size():
		return
	var node_id: String = _search_matches[_search_index]
	_deselect_all_cb.call()
	var view: GNNodeView = _node_views.get(node_id, null)
	if view != null:
		view.selected = true
	_scroll_to_node_cb.call(node_id)


func _apply_search_modulation() -> void:
	var match_set := {}
	for nid in _search_matches:
		match_set[nid] = true

	for node_id in _node_views:
		var view: GNNodeView = _node_views[node_id]
		if match_set.has(node_id):
			view.modulate = Color.WHITE
		else:
			view.modulate = Color(1, 1, 1, 0.25)
	_search_dimmed = true


func _restore_search_modulation() -> void:
	if not _search_dimmed:
		return
	for node_id in _node_views:
		var view: GNNodeView = _node_views[node_id]
		view.modulate = Color.WHITE
	_search_dimmed = false
