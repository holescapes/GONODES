class_name GridWarpPanel
extends MapperOverlay
## Grid warp overlay — maps dragged UV back to per-point offset parameters.

signal point_offset_changed(grid_x: int, grid_y: int, offset: Vector2)


func handle_pointer(uv: Vector2, event: InputEvent) -> bool:
	if grid_cols < 2 or grid_rows < 2:
		return false

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var hit := hit_test_uv(uv, grab_radius_uv)
				if hit >= 0:
					_dragging_index = hit
					active_index = hit
					queue_redraw()
					return true
			elif _dragging_index >= 0:
				_dragging_index = -1
				active_index = -1
				queue_redraw()
				return true

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _dragging_index >= 0:
			if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
				_dragging_index = -1
				active_index = -1
				queue_redraw()
				return true
			var x: int = _dragging_index % grid_cols
			var y: int = _dragging_index / grid_cols
			var base_u: float = float(x) / float(grid_cols - 1)
			var base_v: float = float(y) / float(grid_rows - 1)
			var offset := Vector2(uv.x - base_u, uv.y - base_v)
			offset = Vector2(clampf(offset.x, -1.0, 1.0), clampf(offset.y, -1.0, 1.0))
			if _dragging_index < points.size():
				points[_dragging_index] = Vector2(base_u + offset.x, base_v + offset.y)
			point_offset_changed.emit(x, y, offset)
			queue_redraw()
			_emit_interaction_changed()
			return true
		var hit := hit_test_uv(uv, grab_radius_uv)
		if hit != hovered_index:
			hovered_index = hit
			queue_redraw()
			return hit >= 0

	return false
