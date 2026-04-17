class_name GNGeoRenderer
extends GNDataRenderer
## Renders GNGeoData in the viewer (3D mesh with orbit camera).

## Shared 3D scene nodes for geometry display.
static var _viewer_camera: Camera3D = null
static var _viewer_light: DirectionalLight3D = null
static var _viewer_gizmo: Node3D = null
static var _viewer_mesh_instance: MeshInstance3D = null
static var _viewer_env_node: WorldEnvironment = null


func supports_wireframe() -> bool:
	return true


static func _ensure_viewer_scene() -> void:
	if _viewer_camera != null:
		return
	var scene := GNViewerRenderHelpers.create_3d_viewer_scene(
		Color(0.1, 0.1, 0.12), Color(0.2, 0.2, 0.25))
	_viewer_camera = scene.camera
	_viewer_light = scene.light
	_viewer_gizmo = scene.gizmo
	_viewer_env_node = scene.env_node
	_viewer_mesh_instance = MeshInstance3D.new()


## Re-parents the shared SOP viewer nodes into [param vp].
## Called by COMP operators that render geometry in their viewer override.
static func _reparent_viewer_nodes(vp: SubViewport) -> void:
	_ensure_viewer_scene()
	GNViewerRenderHelpers.reparent_viewer_nodes(
		[_viewer_camera, _viewer_light, _viewer_mesh_instance, _viewer_gizmo, _viewer_env_node], vp)


func render_for_viewer(data: GNData, viewer) -> void:
	if data is GNGeoData:
		var geo: GNGeoData = data as GNGeoData
		if geo.mesh != null:
			_ensure_viewer_scene()
			var vp: SubViewport = viewer.get_3d_viewport()
			GNViewerRenderHelpers.reparent_viewer_nodes(
				[_viewer_camera, _viewer_light, _viewer_mesh_instance, _viewer_gizmo, _viewer_env_node], vp)
			GNViewerRenderHelpers.apply_orbit_camera(
				_viewer_camera, viewer.orbit_yaw, viewer.orbit_pitch, viewer.orbit_distance)
			GNViewerRenderHelpers.update_gizmo_scale(_viewer_gizmo, viewer.orbit_distance)
			GNViewerRenderHelpers.render_sop(vp, _viewer_mesh_instance, geo.mesh, viewer.wireframe)
			viewer.set_info_bar("%d verts" % geo.vertex_count)
			return
	viewer.set_info("No SOP output", "")


func handle_viewer_input(_data: GNData, event: InputEvent, viewer) -> bool:
	return GNViewerRenderHelpers.handle_orbit_input(event, viewer)
