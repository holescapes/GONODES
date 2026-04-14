class_name GNTextureRenderer
extends GNDataRenderer
## Renders GNTextureData in the viewer (texture display with resolution info).


func render_for_viewer(data: GNData, viewer) -> void:
	if data is GNTextureData:
		var td: GNTextureData = data as GNTextureData
		if td.texture:
			viewer.set_texture(td.texture,
				"%dx%d" % [td.resolution.x, td.resolution.y])
			viewer.set_texture_overlay(null)
			return
	viewer.set_info("No texture output", "")


func render_for_preview(data: GNData, host) -> void:
	if data is GNTextureData:
		var td: GNTextureData = data as GNTextureData
		if td.texture != null and host.has_method("set_texture"):
			host.set_texture(td.texture)
			return
	if host.has_method("set_text"):
		host.set_text("")
