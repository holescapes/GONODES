class_name GNInteractivePanel
extends Control
## Base for UV-space interactive overlays shared by the viewer panel and UI ports.
##
## Draw and pointer logic live here once. Hosts call [method handle_pointer] with
## normalized UV (0–1); [code]gui_input[/code] maps local pixels automatically.

signal interaction_changed

## Grab radius in normalized UV space for handle hit tests.
var grab_radius_uv: float = 0.04


func _enter_tree() -> void:
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)


func _configure_for_panel_export() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_STOP


func uv_to_px(uv: Vector2) -> Vector2:
	return Vector2(uv.x * size.x, uv.y * size.y)


func px_to_uv(px: Vector2) -> Vector2:
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	return Vector2(px.x / size.x, px.y / size.y)


## Unified pointer entry for viewer bridge and WindowOUT [code]gui_input[/code].
## Return [code]true[/code] when the event is consumed (drag, hover capture).
func handle_pointer(_uv: Vector2, _event: InputEvent) -> bool:
	return false


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		var uv := px_to_uv((event as InputEventMouse).position)
		if handle_pointer(uv, event):
			accept_event()


func _emit_interaction_changed() -> void:
	interaction_changed.emit()
