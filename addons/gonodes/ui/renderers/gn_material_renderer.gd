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
	_viewer_camera = Camera3D.new()
	_viewer_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_viewer_camera.fov = 45.0
	_viewer_camera.position = Vector3(0, 0, 2.5)
	_viewer_camera.look_at_from_position(Vector3(0, 0, 2.5), Vector3.ZERO)

	_viewer_light = DirectionalLight3D.new()
	_viewer_light.rotation_degrees = Vector3(-45, 30, 0)

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.8
	sphere_mesh.height = 1.6
	sphere_mesh.radial_segments = 64
	sphere_mesh.rings = 32
	_viewer_sphere = MeshInstance3D.new()
	_viewer_sphere.mesh = sphere_mesh

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.15, 0.15, 0.18)
	env.ambient_light_color = Color(0.3, 0.3, 0.35)
	env.ambient_light_energy = 0.5
	_viewer_environment = WorldEnvironment.new()
	_viewer_environment.environment = env


static func _reparent_viewer_nodes(vp: SubViewport) -> void:
	for node in [_viewer_camera, _viewer_light, _viewer_sphere, _viewer_environment]:
		if node.get_parent() != vp:
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			vp.add_child(node)


func render_for_viewer(data: GNData, viewer) -> void:
	if data is GNMaterialData:
		var mat_data: GNMaterialData = data as GNMaterialData
		if mat_data.material != null:
			_ensure_viewer_scene()
			var vp: SubViewport = viewer.get_3d_viewport()
			_reparent_viewer_nodes(vp)
			GNViewerRenderHelpers.render_mat(vp, _viewer_sphere, mat_data.material)
			viewer.set_info_bar("Material: %s" % mat_data.material.get_class())
			return
	viewer.set_info("No MAT output", "")


func render_for_preview(data: GNData, host) -> void:
	if data != null and host.has_method("set_text"):
		host.set_text(data.get_preview_text())
	elif host.has_method("set_text"):
		host.set_text("")
