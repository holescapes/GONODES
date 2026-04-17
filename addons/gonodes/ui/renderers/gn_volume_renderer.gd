class_name GNVolumeRenderer
extends GNDataRenderer
## Renders GNVolumeData in the viewer via GPU compute → Texture2DRD (zero-copy).


func render_for_viewer(data: GNData, viewer) -> void:
	if data is GNVolumeData:
		var vd: GNVolumeData = data as GNVolumeData
		if vd.has_volume():
			var size: Vector2i = viewer.get_content_size()
			var tex := GNViewerRenderHelpers.render_vol_gpu(
				vd, size, viewer.vol_slice_pos, viewer.vol_show_mip)
			if tex != null:
				var info := "%dx%dx%d %s (slice %.0f%%)" % [
					vd.resolution.x, vd.resolution.y, vd.resolution.z,
					vd.field_name, viewer.vol_slice_pos * 100.0]
				viewer.set_texture(tex, info)
				return
	viewer.set_info("No VOL output", "")


func handle_viewer_input(_data: GNData, event: InputEvent, viewer) -> bool:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			viewer.vol_slice_pos = clampf(viewer.vol_slice_pos + 0.02, 0.0, 1.0)
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			viewer.vol_slice_pos = clampf(viewer.vol_slice_pos - 0.02, 0.0, 1.0)
			return true
	return false
