class_name GNMaterialRenderer
extends GNDataRenderer
## Renders GNMaterialData in the viewer (preview sphere in 3D viewport).

## Shared 3D scene nodes for material preview.
static var _viewer_camera: Camera3D = null
static var _viewer_light: DirectionalLight3D = null
static var _viewer_sphere: MeshInstance3D = null
static var _viewer_environment: WorldEnvironment = null


static func _ensure_viewer_scene() -> void:
	if _viewer_camera != null:
		return
	var scene := GNViewerRenderHelpers.create_3d_viewer_scene(
		Color(0.15, 0.15, 0.18), Color(0.3, 0.3, 0.35))
	_viewer_camera = scene.camera
	_viewer_camera.position = Vector3(0, 0, 2.5)
	_viewer_camera.look_at_from_position(Vector3(0, 0, 2.5), Vector3.ZERO)
	_viewer_light = scene.light
	_viewer_environment = scene.env_node

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.8
	sphere_mesh.height = 1.6
	sphere_mesh.radial_segments = 64
	sphere_mesh.rings = 32
	_viewer_sphere = MeshInstance3D.new()
	_viewer_sphere.mesh = sphere_mesh


func render_for_viewer(data: GNData, viewer) -> void:
	if data is GNMaterialData:
		var mat_data: GNMaterialData = data as GNMaterialData
		if mat_data.material != null:
			_ensure_viewer_scene()
			var vp: SubViewport = viewer.get_3d_viewport()
			GNViewerRenderHelpers.reparent_viewer_nodes(
				[_viewer_camera, _viewer_light, _viewer_sphere, _viewer_environment], vp)
			GNViewerRenderHelpers.render_mat(vp, _viewer_sphere, mat_data.material)
			viewer.set_info_bar("Material: %s" % mat_data.material.get_class())
			return
	viewer.set_info("No MAT output", "")
