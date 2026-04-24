class_name GNAnnotationManager
extends RefCounted
## Manages network box and sticky note annotations for GNGraphEditor.
## Handles creation, deletion, sync, and group-move of annotation Controls.

var _graph: GraphEdit = null
var _node_views: Dictionary  # Reference to GNGraphEditor._node_views
var network: GNNetwork = null

## Annotation views: ann_id -> GNNetworkBox or GNStickyNote.
var _annotation_views: Dictionary = {}

## Guard flag to prevent recursive group-move updates.
var _group_moving: bool = false

## Last-known zoom/scroll for sync.
var _last_zoom: float = 0.8
var _last_scroll: Vector2 = Vector2.ZERO

## Box drag state.
var _box_drag_pre_positions: Dictionary = {}
var _box_drag_pre_box_pos: Vector2 = Vector2.ZERO
var _box_drag_ann_id: String = ""

var _undo_redo: UndoRedo = null
var _ur_set_positions_cb: Callable


func setup(graph: GraphEdit, node_views: Dictionary, net: GNNetwork,
		undo_redo: UndoRedo, ur_set_positions: Callable) -> void:
	_graph = graph
	_node_views = node_views
	network = net
	_undo_redo = undo_redo
	_ur_set_positions_cb = ur_set_positions
	_last_zoom = graph.zoom
	_last_scroll = graph.scroll_offset


func set_network(net: GNNetwork) -> void:
	network = net


func has_annotations() -> bool:
	return not _annotation_views.is_empty()


## Returns the annotation views dictionary (ann_id → Control).
func get_annotation_views() -> Dictionary:
	return _annotation_views


func is_box_dragging() -> bool:
	return not _box_drag_ann_id.is_empty()


func is_group_moving() -> bool:
	return _group_moving


## Checks if scroll/zoom changed and syncs annotations. Called from _process.
func sync_if_needed(current_zoom: float, current_scroll: Vector2) -> void:
	if _annotation_views.is_empty():
		return
	if current_zoom != _last_zoom or current_scroll != _last_scroll:
		_last_zoom = current_zoom
		_last_scroll = current_scroll
		sync_transforms()


func add_annotation_at_mouse(ann_type: String, selected_ids: Array[String],
		mouse_pos: Vector2) -> void:
	if network == null:
		return

	var default_color := Color(0.15, 0.35, 0.65, 0.7) if ann_type == "box" else Color(0.9, 0.85, 0.4, 0.9)
	var default_text := "Group" if ann_type == "box" else "Note"

	var graph_pos: Vector2
	var graph_size: Vector2
	var zoom: float = _graph.zoom
	var scroll: Vector2 = _graph.scroll_offset

	if not selected_ids.is_empty():
		var padding := 30.0
		var title_pad := 28.0 if ann_type == "box" else 0.0
		var first_view: GNNodeView = _node_views[selected_ids[0]]
		var rect := Rect2(first_view.position_offset, first_view.size)
		for i in range(1, selected_ids.size()):
			var v: GNNodeView = _node_views[selected_ids[i]]
			rect = rect.merge(Rect2(v.position_offset, v.size))
		var gpad := padding / zoom
		var gtitle := title_pad / zoom
		graph_pos = rect.position - Vector2(gpad, gpad + gtitle)
		graph_size = rect.size + Vector2(gpad * 2.0, gpad * 2.0 + gtitle)
	else:
		graph_pos = (mouse_pos + scroll) / zoom
		graph_size = Vector2(300, 200) if ann_type == "box" else Vector2(200, 120)

	var ann_id := network.add_annotation(ann_type, graph_pos, graph_size, default_text, default_color)
	_create_annotation_view(network.get_annotation(ann_id))


func _create_annotation_view(ann: Variant) -> void:
	if ann == null or not ann is Dictionary:
		return
	var ann_dict: Dictionary = ann as Dictionary
	var ann_id: String = ann_dict.get("id", "")
	var ann_type: String = ann_dict.get("type", "")
	var ann_pos: Variant = ann_dict.get("position", Vector2.ZERO)
	var ann_size: Variant = ann_dict.get("size", Vector2(200, 150))
	var ann_text: String = str(ann_dict.get("text", ""))
	var ann_color: Variant = ann_dict.get("color", Color(0.3, 0.3, 0.3, 0.4))

	var pos := ann_pos if ann_pos is Vector2 else Vector2.ZERO
	var sz := ann_size if ann_size is Vector2 else Vector2(200, 150)
	var col := ann_color if ann_color is Color else Color(0.3, 0.3, 0.3, 0.4)

	var zoom: float = _graph.zoom
	var scroll: Vector2 = _graph.scroll_offset
	var pixel_pos: Vector2 = pos * zoom - scroll
	var pixel_size: Vector2 = sz * zoom

	if ann_type == "box":
		var box := GNNetworkBox.new()
		box.setup(ann_id, pixel_pos, pixel_size, ann_text, col)
		box.box_changed.connect(_on_annotation_moved)
		box.text_changed.connect(_on_annotation_text_changed)
		box.delete_requested.connect(_on_annotation_delete_requested)
		box.color_changed.connect(_on_annotation_color_changed)
		box.box_dragging.connect(_on_box_dragging)
		box.drag_started.connect(_on_box_drag_started)
		box.drag_ended.connect(_on_box_drag_ended)
		_graph.add_child(box)
		_graph.move_child(box, 0)
		_annotation_views[ann_id] = box
	elif ann_type == "note":
		var note := GNStickyNote.new()
		note.setup(ann_id, pixel_pos, pixel_size, ann_text, col)
		note.note_changed.connect(_on_annotation_moved)
		note.text_changed.connect(_on_annotation_text_changed)
		note.delete_requested.connect(_on_annotation_delete_requested)
		note.color_changed.connect(_on_annotation_color_changed)
		_graph.add_child(note)
		_graph.move_child(note, 0)
		_annotation_views[ann_id] = note


func rebuild_views() -> void:
	clear_views()
	if network == null:
		return
	for ann in network.annotations:
		_create_annotation_view(ann)
	_last_zoom = _graph.zoom
	_last_scroll = _graph.scroll_offset


func sync_transforms() -> void:
	if network == null:
		return
	var zoom: float = _graph.zoom
	var scroll: Vector2 = _graph.scroll_offset
	for ann_id in _annotation_views:
		var ann: Variant = network.get_annotation(ann_id)
		if ann == null:
			continue
		var view: Control = _annotation_views[ann_id]
		var graph_pos: Variant = ann.get("position", Vector2.ZERO)
		var graph_size: Variant = ann.get("size", Vector2(200, 150))
		var gp: Vector2 = graph_pos if graph_pos is Vector2 else Vector2.ZERO
		var gs: Vector2 = graph_size if graph_size is Vector2 else Vector2(200, 150)
		view.position = gp * zoom - scroll
		view.size = gs * zoom


func clear_views() -> void:
	for ann_id in _annotation_views:
		var view: Control = _annotation_views[ann_id]
		if view != null and is_instance_valid(view):
			_graph.remove_child(view)
			view.queue_free()
	_annotation_views.clear()


func _on_annotation_moved(ann_id: String, new_pos: Vector2, new_size: Vector2) -> void:
	if network:
		var graph_pos := (new_pos + _graph.scroll_offset) / _graph.zoom
		var graph_size := new_size / _graph.zoom
		network.update_annotation(ann_id, {"position": graph_pos, "size": graph_size})


func _on_annotation_text_changed(ann_id: String, new_text: String) -> void:
	if network:
		network.update_annotation(ann_id, {"text": new_text})


func _on_annotation_delete_requested(ann_id: String) -> void:
	if network:
		network.remove_annotation(ann_id)
	if _annotation_views.has(ann_id):
		var view: Control = _annotation_views[ann_id]
		_annotation_views.erase(ann_id)
		if view != null and is_instance_valid(view):
			_graph.remove_child(view)
			view.queue_free()


func _on_annotation_color_changed(ann_id: String, new_color: Color) -> void:
	if network:
		network.update_annotation(ann_id, {"color": new_color})


func get_nodes_inside_box(box_pos: Vector2, box_size: Vector2) -> Array[String]:
	var ids: Array[String] = []
	var box_rect := Rect2(box_pos, box_size)
	var zoom: float = _graph.zoom
	var scroll: Vector2 = _graph.scroll_offset
	for view_name in _node_views:
		var view: GNNodeView = _node_views[view_name]
		var center := view.position_offset * zoom - scroll + view.size * zoom / 2.0
		if box_rect.has_point(center):
			ids.append(view_name)
	return ids


func _on_box_drag_started(ann_id: String) -> void:
	_box_drag_ann_id = ann_id
	_box_drag_pre_positions.clear()
	var box_view: GNNetworkBox = _annotation_views.get(ann_id) as GNNetworkBox
	if box_view == null:
		return
	_box_drag_pre_box_pos = box_view.position
	var contained := get_nodes_inside_box(box_view.position, box_view.size)
	for node_id in contained:
		_box_drag_pre_positions[node_id] = _node_views[node_id].position_offset


func _on_box_dragging(ann_id: String, delta: Vector2) -> void:
	if _group_moving:
		return
	_group_moving = true
	var graph_delta := delta / _graph.zoom
	for node_id in _box_drag_pre_positions:
		if _node_views.has(node_id):
			var view: GNNodeView = _node_views[node_id]
			view.position_offset += graph_delta
			if network and network.nodes.has(node_id):
				network.nodes[node_id].graph_position = view.position_offset
	_group_moving = false


func _on_box_drag_ended(ann_id: String) -> void:
	if _box_drag_pre_positions.is_empty():
		_box_drag_ann_id = ""
		return

	var old_positions := _box_drag_pre_positions.duplicate()
	var new_positions: Dictionary = {}
	var changed := false
	for node_id in old_positions:
		if _node_views.has(node_id):
			var new_pos: Vector2 = _node_views[node_id].position_offset
			new_positions[node_id] = new_pos
			if new_pos != old_positions[node_id]:
				changed = true

	if changed:
		_undo_redo.create_action("Move box group (%d nodes)" % old_positions.size())
		_undo_redo.add_do_method(_ur_set_positions_cb.bind(new_positions))
		_undo_redo.add_undo_method(_ur_set_positions_cb.bind(old_positions))
		_undo_redo.commit_action(false)

	_box_drag_pre_positions.clear()
	_box_drag_ann_id = ""


## Move annotation views during a node drag (called from GNGraphEditor._process).
func apply_drag_delta(pixel_delta: Vector2, frame_delta: Vector2,
		node_drag_ann_info: Dictionary) -> void:
	_group_moving = true
	for ann_id in node_drag_ann_info:
		var info: Dictionary = node_drag_ann_info[ann_id]
		if _annotation_views.has(ann_id):
			_annotation_views[ann_id].position += pixel_delta
		var siblings: Dictionary = info.get("siblings", {})
		for sib_id in siblings:
			if _node_views.has(sib_id):
				_node_views[sib_id].position_offset += frame_delta
	_group_moving = false
