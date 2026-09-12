class_name GNTopInteractiveBase
extends GNTopBase
## TOP base with optional interactive [code]panel[/code] UI output for WindowOUT.
##
## Subclasses implement [method _create_interactive_panel], [method _sync_panel_from_params],
## and [method _sync_params_from_panel]. Call [method add_panel_output] from
## [method _init_ports] after primary outputs.

const PANEL_PORT_NAME := "panel"

var _interactive_panel: GNInteractivePanel = null
var _panel_port_index: int = -1
var _viewer_texture_port_index: int = 0
var _cached_panel_ui_data: GNUIData = null


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


func _sync_panel_from_params() -> void:
	pass


func _sync_params_from_panel() -> void:
	pass


func _ensure_interactive_panel() -> GNInteractivePanel:
	if _interactive_panel == null:
		_interactive_panel = _create_interactive_panel()
		if _interactive_panel != null:
			_interactive_panel.name = id + "_panel"
			_interactive_panel._configure_for_panel_export()
			if not _interactive_panel.interaction_changed.is_connected(_on_interactive_panel_changed):
				_interactive_panel.interaction_changed.connect(_on_interactive_panel_changed)
	return _interactive_panel


func _on_interactive_panel_changed() -> void:
	_sync_params_from_panel()
	mark_dirty()


func _is_panel_port_demanded() -> bool:
	return _panel_port_index >= 0 and is_output_demanded(_panel_port_index)


func _get_panel_ui_data() -> GNUIData:
	if _panel_port_index < 0:
		return null
	_ensure_interactive_panel()
	_sync_panel_from_params()
	if _cached_panel_ui_data == null:
		_cached_panel_ui_data = GNUIData.new()
	_cached_panel_ui_data.control_node = _interactive_panel
	_cached_panel_ui_data.control_label = node_type
	_cached_panel_ui_data.valid = _interactive_panel != null
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
	if port_index != _viewer_texture_port_index or _is_panel_port_demanded():
		return false
	var panel := _ensure_interactive_panel()
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
			if _is_panel_port_demanded():
				viewer.set_texture_overlay(null)
			else:
				_ensure_interactive_panel()
				_sync_panel_from_params()
				viewer.set_interactive_texture_overlay(_interactive_panel)
			return
	viewer.set_info("No texture output", "")


func _render_panel_port_in_viewer(viewer) -> void:
	_ensure_interactive_panel()
	_sync_panel_from_params()
	if _interactive_panel == null:
		viewer.set_info("No interactive panel", "")
		return
	var preview: Control = _interactive_panel.duplicate()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info := "Interactive panel"
	if _is_panel_port_demanded():
		info += " (live in WindowOUT)"
	viewer.set_control(preview, info)
