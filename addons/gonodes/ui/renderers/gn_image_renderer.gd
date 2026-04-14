class_name GNImageRenderer
extends GNDataRenderer
## Renders GNImageData in the viewer (CPU-side image → ImageTexture).

## Shared ImageTexture for uploading CPU Images to the viewer.
static var _viewer_texture: ImageTexture = null


func render_for_viewer(data: GNData, viewer) -> void:
	if data is GNImageData:
		var img_data: GNImageData = data as GNImageData
		if img_data.image != null and not img_data.image.is_empty():
			var img: Image = img_data.image
			if _viewer_texture == null \
					or _viewer_texture.get_width() != img.get_width() \
					or _viewer_texture.get_height() != img.get_height():
				_viewer_texture = ImageTexture.create_from_image(img)
			else:
				_viewer_texture.update(img)
			viewer.set_texture(_viewer_texture,
				"%dx%d" % [img_data.resolution.x, img_data.resolution.y])
			return
	viewer.set_info("No IMG output", "")


func render_for_preview(data: GNData, host) -> void:
	if data is GNImageData:
		var img_data: GNImageData = data as GNImageData
		if img_data.image != null and not img_data.image.is_empty() and host.has_method("set_texture"):
			if _viewer_texture == null \
					or _viewer_texture.get_width() != img_data.image.get_width() \
					or _viewer_texture.get_height() != img_data.image.get_height():
				_viewer_texture = ImageTexture.create_from_image(img_data.image)
			else:
				_viewer_texture.update(img_data.image)
			host.set_texture(_viewer_texture)
			return
	if host.has_method("set_text"):
		host.set_text("")
