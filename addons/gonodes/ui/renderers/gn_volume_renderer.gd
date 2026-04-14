class_name GNVolumeRenderer
extends GNDataRenderer
## Renders GNVolumeData in the viewer (2×2 slice composite with scroll interaction).

## Shared ImageTexture for uploading composites to the viewer.
static var _viewer_texture: ImageTexture = null


func render_for_viewer(data: GNData, viewer) -> void:
	if data is GNVolumeData:
		var vd: GNVolumeData = data as GNVolumeData
		if vd.has_volume():
			var size: Vector2i = viewer.get_content_size()
			var img := GNViewerRenderHelpers.render_vol_composite(
				vd, size, viewer.vol_slice_pos, viewer.vol_show_mip)
			if _viewer_texture == null \
					or _viewer_texture.get_width() != img.get_width() \
					or _viewer_texture.get_height() != img.get_height():
				_viewer_texture = ImageTexture.create_from_image(img)
			else:
				_viewer_texture.update(img)
			var info := "%dx%dx%d %s (slice %.0f%%)" % [
				vd.resolution.x, vd.resolution.y, vd.resolution.z,
				vd.field_name, viewer.vol_slice_pos * 100.0]
			viewer.set_texture(_viewer_texture, info)
			return
	viewer.set_info("No VOL output", "")


func render_for_preview(data: GNData, host) -> void:
	if data != null and host.has_method("set_text"):
		host.set_text(data.get_preview_text())
	elif host.has_method("set_text"):
		host.set_text("")


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
