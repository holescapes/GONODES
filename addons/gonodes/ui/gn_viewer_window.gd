class_name GNViewerWindow
extends Window
## A floating viewer window that displays a TOP node's texture output.
##
## Each viewer window is pinned to a specific node and updates its content
## every cook frame.  Supports all TOP outputs (including RenderTOP 3D scenes).
##
## Features:
##   • Pinned to a specific node via node_id (persists on rename)
##   • Updates every cook frame via update_texture()
##   • Title bar shows "Viewer — <node_id>"
##   • Resize-friendly with aspect-ratio-preserving display
##   • Close button frees the window (emits closed signal for cleanup)

## Emitted when the user closes this viewer window.
signal closed(viewer: GNViewerWindow)

## The node ID this viewer is pinned to.
var node_id: String = "":
	set(value):
		node_id = value
		_update_title()

## Internal display rect.
var _display_rect: TextureRect = null

## Background panel so the window has a dark fill.
var _bg: ColorRect = null


func _init() -> void:
	title = "Viewer"
	size = Vector2i(640, 480)
	min_size = Vector2i(200, 150)
	close_requested.connect(_on_close_requested)
	# Don't grab focus from the main editor when created
	unresizable = false
	always_on_top = false


func _ready() -> void:
	# Dark background
	_bg = ColorRect.new()
	_bg.color = Color(0.08, 0.08, 0.1)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# TextureRect for displaying TOP output
	_display_rect = TextureRect.new()
	_display_rect.name = "Display"
	_display_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_display_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_display_rect)


## Called each cook frame by the editor to update the displayed texture.
func update_texture(texture: Texture2D) -> void:
	if _display_rect == null:
		return
	if texture != null:
		_display_rect.texture = texture
		_display_rect.visible = true
	else:
		_display_rect.texture = null
		_display_rect.visible = false


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
