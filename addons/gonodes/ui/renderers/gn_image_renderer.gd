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
			_viewer_texture = _upload_viewer_texture(img, _viewer_texture)
			viewer.set_texture(_viewer_texture,
				"%dx%d" % [img_data.resolution.x, img_data.resolution.y])
			return
	viewer.set_info("No IMG output", "")


func render_for_preview(data: GNData, host) -> void:
	if data is GNImageData:
		var img_data: GNImageData = data as GNImageData
		if img_data.image != null and not img_data.image.is_empty() and host.has_method("set_texture"):
			_viewer_texture = _upload_viewer_texture(img_data.image, _viewer_texture)
			host.set_texture(_viewer_texture)
			return
	if host.has_method("set_text"):
		host.set_text("")


## Recreate when size or format changes — ImageTexture.update() requires both to match
## (e.g. switching JPG/RGB8 ↔ PNG/RGBA8 at the same resolution).
static func _upload_viewer_texture(img: Image, tex: ImageTexture) -> ImageTexture:
	if tex == null \
			or tex.get_width() != img.get_width() \
			or tex.get_height() != img.get_height() \
			or tex.get_format() != img.get_format():
		return ImageTexture.create_from_image(img)
	tex.update(img)
	return tex
