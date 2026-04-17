class_name GNParticleRenderer
extends GNDataRenderer
## Renders GNParticleData in the viewer via GPU compute → Texture2DRD (zero-copy).


func render_for_viewer(data: GNData, viewer) -> void:
	if data is GNParticleData:
		var pd: GNParticleData = data as GNParticleData
		if pd.particle_count > 0:
			var size: Vector2i = viewer.get_content_size()
			var tex := GNViewerRenderHelpers.render_pop_gpu(
				pd, size, viewer.orbit_yaw, viewer.orbit_pitch, viewer.orbit_distance)
			if tex != null:
				viewer.set_texture(tex, "%d particles" % pd.particle_count)
				return
	viewer.set_info("No POP output", "")


func handle_viewer_input(_data: GNData, event: InputEvent, viewer) -> bool:
	return GNViewerRenderHelpers.handle_orbit_input(event, viewer)
