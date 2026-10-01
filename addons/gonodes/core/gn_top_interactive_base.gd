class_name GNTopInteractiveBase
extends GNTopBase
## TOP base with optional interactive [code]panel[/code] UI output for WindowOUT.
##
## Params are the source of truth. The viewer overlay and WindowOUT each get
## their own [GNInteractivePanel] instance (N views, one model). Dragging either
## writes params, then all live views refresh from params.
##
## Subclasses implement [method _create_interactive_panel],
## [method _sync_panel_from_params], and [method _sync_params_from_panel]
## (read/write via [member _interactive_panel], which the base sets per view).
## Call [method add_panel_output] from [method _init_ports] after primary outputs.
## From [method _cook], call [method _sync_panel_from_params_if_live].

const PANEL_PORT_NAME := "panel"

## Active panel during a sync call. Subclasses cast this to their panel type
## inside [method _sync_panel_from_params] / [method _sync_params_from_panel].
var _interactive_panel: GNInteractivePanel = null

var _viewer_panel: GNInteractivePanel = null
var _export_panel: GNInteractivePanel = null
var _panel_port_index: int = -1
var _viewer_texture_port_index: int = 0
var _cached_panel_ui_data: GNUIData = null
var _syncing_views: bool = false


func add_panel_output(desc: String = "Interactive panel for WindowOUT") -> void:
	_panel_port_index = output_ports.size()
	add_output(PANEL_PORT_NAME, GNFamily.Type.UI, desc, "Panel")


func has_panel_output() -> bool:
	return _panel_port_index >= 0


func get_panel_port_index() -> int:
	return _panel_port_index


func _create_interactive_panel() -> GNInteractivePanel:
	push_error("GNTopInteractiveBase: _create_interactive_panel() not implemented on '%s'" % id)
	return null


## Override: copy node params onto [member _interactive_panel] (set by the base
## before each call). Cast [member _interactive_panel] to your panel type.
func _sync_panel_from_params() -> void:
	pass


## Override: copy [member _interactive_panel] state into node params.
func _sync_params_from_panel() -> void:
	pass


func _ensure_viewer_panel() -> GNInteractivePanel:
	_purge_stale_view_refs()
	if _viewer_panel == null:
		_viewer_panel = _spawn_panel_instance("_viewer_panel")
	_rehome_if_orphaned(_viewer_panel)
	return _viewer_panel


func _ensure_export_panel() -> GNInteractivePanel:
	_purge_stale_view_refs()
	if _export_panel == null:
		_export_panel = _spawn_panel_instance("_export_panel")
	_rehome_if_orphaned(_export_panel)
	return _export_panel


## Back-compat: ensures the viewer panel (primary overlay host).
func _ensure_interactive_panel() -> GNInteractivePanel:
	return _ensure_viewer_panel()


func _spawn_panel_instance(suffix: String) -> GNInteractivePanel:
	var panel := _create_interactive_panel()
	if panel == null:
		return null
	panel.name = id + suffix
	panel._configure_for_panel_export()
	panel.bind_storage_parent(self)
	if not panel.interaction_changed.is_connected(_on_view_interaction):
		panel.interaction_changed.connect(_on_view_interaction.bind(panel))
	add_child(panel)
	panel.visible = false
	return panel


func _purge_stale_view_refs() -> void:
	if _viewer_panel != null and not is_instance_valid(_viewer_panel):
		_viewer_panel = null
	if _export_panel != null and not is_instance_valid(_export_panel):
		_export_panel = null
	if _interactive_panel != null and not is_instance_valid(_interactive_panel):
		_interactive_panel = null


func _rehome_if_orphaned(panel: GNInteractivePanel) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	if panel.get_parent() == null:
		add_child(panel)
		panel.visible = false


func _live_panels() -> Array[GNInteractivePanel]:
	_purge_stale_view_refs()
	var out: Array[GNInteractivePanel] = []
	if _viewer_panel != null:
		out.append(_viewer_panel)
	if _export_panel != null:
		out.append(_export_panel)
	return out


## Push params → every live view. Call from [method _cook].
func _sync_panel_from_params_if_live() -> void:
	_push_params_to_all_views()


func _push_params_to_all_views() -> void:
	if _syncing_views:
		return
	_syncing_views = true
	for panel in _live_panels():
		_interactive_panel = panel
		_sync_panel_from_params()
	_interactive_panel = _viewer_panel if _viewer_panel != null else _export_panel
	_syncing_views = false


func _on_view_interaction(source: GNInteractivePanel) -> void:
	if _syncing_views:
		return
	if source == null or not is_instance_valid(source):
		return
	_interactive_panel = source
	_sync_params_from_panel()
	mark_dirty()
	_push_params_to_all_views()


## Legacy signal path (unbound). Prefer [method _on_view_interaction].
func _on_interactive_panel_changed() -> void:
	if is_instance_valid(_interactive_panel):
		_on_view_interaction(_interactive_panel)


func _is_panel_port_demanded() -> bool:
	return _panel_port_index >= 0 and is_output_demanded(_panel_port_index)


func _get_panel_ui_data() -> GNUIData:
	if _panel_port_index < 0:
		return null
	var panel := _ensure_export_panel()
	_interactive_panel = panel
	_sync_panel_from_params()
	if _cached_panel_ui_data == null:
		_cached_panel_ui_data = GNUIData.new()
	_cached_panel_ui_data.control_node = panel
	_cached_panel_ui_data.control_label = node_type
	_cached_panel_ui_data.valid = panel != null
	_cached_panel_ui_data.timestamp = Engine.get_process_frames()
	_cached_panel_ui_data.source_id = id
	_cached_panel_ui_data.widget_state = {}
	return _cached_panel_ui_data


func get_output_data(port_index: int) -> GNData:
	if port_index == _panel_port_index:
		if not _is_panel_port_demanded():
			return null
		return _get_panel_ui_data()
	return super.get_output_data(port_index)


func render_for_viewer(viewer, port_index: int = 0) -> void:
	if port_index == _panel_port_index:
		_render_panel_port_in_viewer(viewer)
		return
	if port_index == _viewer_texture_port_index and has_panel_output():
		_render_texture_with_interactive_panel(viewer, port_index)
		return
	super.render_for_viewer(viewer, port_index)


func handle_viewer_input(event: InputEvent, local_pos: Vector2, viewer = null, port_index: int = 0) -> bool:
	# Primary path is the interactive overlay's handle_pointer via the viewer.
	# Keep this as a fallback when the overlay is not mounted yet.
	if port_index != _viewer_texture_port_index:
		return false
	var panel := _ensure_viewer_panel()
	if panel == null or viewer == null:
		return false
	var uv: Vector2 = viewer.local_pos_to_uv(local_pos)
	if panel.handle_pointer(uv, event):
		return true
	return false


func _render_texture_with_interactive_panel(viewer, port_index: int) -> void:
	var data: GNData = get_output_data(port_index)
	if data is GNTextureData:
		var tex_data: GNTextureData = data as GNTextureData
		if tex_data.texture:
			viewer.set_texture(tex_data.texture,
				"%dx%d" % [tex_data.resolution.x, tex_data.resolution.y])
			var panel := _ensure_viewer_panel()
			_interactive_panel = panel
			_sync_panel_from_params()
			panel.show_for_host()
			viewer.set_interactive_texture_overlay(panel)
			return
	viewer.set_info("No texture output", "")


func _render_panel_port_in_viewer(viewer) -> void:
	# Inspection only — do not steal the export instance from WindowOUT.
	var panel := _ensure_export_panel()
	_interactive_panel = panel
	_sync_panel_from_params()
	if panel == null:
		viewer.set_info("No interactive panel", "")
		return
	var preview: Control = panel.duplicate()
	if preview is GNInteractivePanel:
		(preview as GNInteractivePanel).clear_storage_binding()
	preview.visible = true
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info := "Panel export view (synced)"
	if _is_panel_port_demanded():
		info += " — live also in WindowOUT"
	viewer.set_control(preview, info)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_purge_stale_view_refs()
		for panel in [_viewer_panel, _export_panel]:
			if panel != null and is_instance_valid(panel):
				var parent: Node = panel.get_parent()
				if parent != null:
					parent.remove_child(panel)
				panel.queue_free()
		_viewer_panel = null
		_export_panel = null
		_interactive_panel = null
