class_name GNViewerWindow
extends Window
## A floating viewer window that displays any node's output.
##
## Each viewer window is pinned to a specific node and updates its content
## every cook frame via an embedded GNViewerPanel.  Supports all families:
## TOP (pan/zoom), CHOP (waveform), DAT (spreadsheet), SOP (3D), MAT (sphere).
##
## Features:
##   • Pinned to a specific node via node_id (persists on rename)
##   • Updates every cook frame via update_from_node()
##   • Title bar shows "Viewer — <node_id>"
##   • Resize-friendly with family-aware display
##   • Close button frees the window (emits closed signal for cleanup)

## Emitted when the user closes this viewer window.
signal closed(viewer: GNViewerWindow)

## The node ID this viewer is pinned to.
var node_id: String = "":
	set(value):
		node_id = value
		_update_title()
		if _viewer_panel:
			_viewer_panel.set_target(value)

## Internal viewer panel (family-aware display).
var _viewer_panel: GNViewerPanel = null


func _init() -> void:
	title = "Viewer"
	size = Vector2i(640, 480)
	min_size = Vector2i(200, 150)
	close_requested.connect(_on_close_requested)
	unresizable = false
	always_on_top = false


func _ready() -> void:
	_viewer_panel = GNViewerPanel.new()
	_viewer_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_viewer_panel)

	if not node_id.is_empty():
		_viewer_panel.set_target(node_id)


## Called each cook frame by the editor to update the displayed content.
func update_from_node(node: GNNode) -> void:
	if _viewer_panel == null:
		return
	_viewer_panel.update_from_node(node)


## Output port currently selected in the embedded viewer dropdown.
func get_selected_port_index() -> int:
	if _viewer_panel == null:
		return 0
	return _viewer_panel.get_selected_port_index()


## Forward port-selection changes so the editor can update cook demand.
func get_viewer_panel() -> GNViewerPanel:
	return _viewer_panel


## Legacy compat — update with a texture (for backward compatibility).
func update_texture(texture: Texture2D) -> void:
	# Kept for minimal backward compat; prefer update_from_node().
	pass


## Updates the title bar to reflect the pinned node.
func _update_title() -> void:
	if node_id.is_empty():
		title = "Viewer"
	else:
		title = "Viewer — %s" % node_id


## Handle node rename — keep pinned target up to date.
func handle_node_renamed(old_id: String, new_id: String) -> void:
	if node_id == old_id:
		node_id = new_id


func _on_close_requested() -> void:
	closed.emit(self)
	queue_free()
