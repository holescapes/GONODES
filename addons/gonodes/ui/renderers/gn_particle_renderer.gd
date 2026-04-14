class_name GNParticleRenderer
extends GNDataRenderer
## Renders GNParticleData in the viewer (point cloud via MultiMesh + orbit camera).

## Shared 3D scene nodes for particle display.
static var _viewer_camera: Camera3D = null
static var _viewer_light: DirectionalLight3D = null
static var _viewer_gizmo: Node3D = null
static var _viewer_multimesh: MultiMeshInstance3D = null
static var _viewer_env_node: WorldEnvironment = null


static func _ensure_viewer_scene() -> void:
	if _viewer_camera != null:
		return
	_viewer_camera = Camera3D.new()
	_viewer_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_viewer_camera.fov = 45.0

	_viewer_light = DirectionalLight3D.new()
	_viewer_light.rotation_degrees = Vector3(-45, 30, 0)

	_viewer_multimesh = MultiMeshInstance3D.new()

	_viewer_gizmo = GNViewerRenderHelpers._create_axis_gizmo()

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.1)
	env.ambient_light_color = Color(0.3, 0.3, 0.35)
	env.ambient_light_energy = 0.5
	_viewer_env_node = WorldEnvironment.new()
	_viewer_env_node.environment = env


static func _reparent_viewer_nodes(vp: SubViewport) -> void:
	for node in [_viewer_camera, _viewer_light, _viewer_multimesh, _viewer_gizmo, _viewer_env_node]:
		if node.get_parent() != vp:
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			vp.add_child(node)


func render_for_viewer(data: GNData, viewer) -> void:
	if data is GNParticleData:
		var pd: GNParticleData = data as GNParticleData
		if pd.particle_count > 0:
			_ensure_viewer_scene()
			var vp: SubViewport = viewer.get_3d_viewport()
			_reparent_viewer_nodes(vp)
			GNViewerRenderHelpers.apply_orbit_camera(
				_viewer_camera, viewer.orbit_yaw, viewer.orbit_pitch, viewer.orbit_distance)
			GNViewerRenderHelpers.update_gizmo_scale(_viewer_gizmo, viewer.orbit_distance)
			if GNViewerRenderHelpers.render_pop(vp, _viewer_multimesh, pd):
				viewer.set_info_bar("%d particles" % pd.particle_count)
				return
	viewer.set_info("No POP output", "")


func render_for_preview(data: GNData, host) -> void:
	if data != null and host.has_method("set_text"):
		host.set_text(data.get_preview_text())
	elif host.has_method("set_text"):
		host.set_text("")


func handle_viewer_input(_data: GNData, event: InputEvent, viewer) -> bool:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			viewer.orbit_dragging = mb.pressed
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			viewer.orbit_distance = maxf(viewer.orbit_distance * 0.9, 0.5)
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			viewer.orbit_distance = minf(viewer.orbit_distance * 1.1, 50.0)
			return true
	if event is InputEventMouseMotion and viewer.orbit_dragging:
		var mm: InputEventMouseMotion = event
		viewer.orbit_yaw = fmod(viewer.orbit_yaw + mm.relative.x * 0.5, 360.0)
		viewer.orbit_pitch = clampf(viewer.orbit_pitch - mm.relative.y * 0.5, -89.0, 89.0)
		return true
	return false
