extends Node
## Unit tests for viewer overlay drag lifecycle.


func _mouse_button(uv: Vector2, pressed: bool) -> InputEventMouseButton:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = uv
	return mb


func _mouse_motion(uv: Vector2, button_mask: int = MOUSE_BUTTON_MASK_LEFT) -> InputEventMouseMotion:
	var mm := InputEventMouseMotion.new()
	mm.position = uv
	mm.button_mask = button_mask
	return mm


func test_set_texture_overlay_same_instance_no_reparent() -> void:
	var panel := MapperOverlay.new()
	panel.bind_storage_parent(self)
	panel.size = Vector2(256, 256)
	add_child(panel)

	var viewer := GNViewerPanel.new()
	add_child(viewer)
	await viewer.ready

	viewer.set_interactive_texture_overlay(panel)
	var first_parent := panel.get_parent()
	GNTestAssert.assert_eq(first_parent, viewer._tex_overlay, "overlay parented to tex overlay")
	GNTestAssert.assert_true(panel.visible, "overlay visible after first mount")

	viewer.set_interactive_texture_overlay(panel)
	GNTestAssert.assert_eq(panel.get_parent(), first_parent, "second mount keeps same parent")
	GNTestAssert.assert_true(panel.visible, "overlay still visible after redraw mount")
	GNTestAssert.assert_ne(panel.get_parent(), self,
		"overlay not returned to storage between redraws")


func test_mapper_overlay_drag_stores_raw_uv() -> void:
	var overlay := MapperOverlay.new()
	add_child(overlay)
	overlay.size = Vector2(256, 256)
	overlay.points = PackedVector2Array([Vector2(0.5, 0.5)])

	var press := _mouse_button(Vector2(0.5, 0.5), true)
	GNTestAssert.assert_true(overlay.handle_pointer(Vector2(0.5, 0.5), press), "press hits handle")

	var motion := _mouse_motion(Vector2(1.4, -0.2))
	GNTestAssert.assert_true(overlay.handle_pointer(Vector2(1.4, -0.2), motion), "drag motion consumed")
	GNTestAssert.assert_approx(overlay.points[0].x, 1.4, 0.001, "drag x stored unclamped")
	GNTestAssert.assert_approx(overlay.points[0].y, -0.2, 0.001, "drag y stored unclamped")


func test_mapper_overlay_motion_without_button_clears_drag() -> void:
	var overlay := MapperOverlay.new()
	add_child(overlay)
	overlay.size = Vector2(256, 256)
	overlay.points = PackedVector2Array([Vector2(0.5, 0.5)])

	var press := _mouse_button(Vector2(0.5, 0.5), true)
	overlay.handle_pointer(Vector2(0.5, 0.5), press)

	var release_motion := _mouse_motion(Vector2(0.8, 0.8), 0)
	GNTestAssert.assert_true(
		overlay.handle_pointer(Vector2(0.8, 0.8), release_motion),
		"motion without button consumed")
	GNTestAssert.assert_eq(overlay._dragging_index, -1, "drag cleared on button-up motion")

	var after := _mouse_motion(Vector2(0.9, 0.9), 0)
	overlay.handle_pointer(Vector2(0.9, 0.9), after)
	GNTestAssert.assert_approx(overlay.points[0].x, 0.5, 0.001, "point unchanged after drag cleared")
