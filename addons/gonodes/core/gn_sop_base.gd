class_name GNSopBase
extends GNNode
## Base class for all SOP (Surface Operator) family operators.
##
## Provides:
##   • family = GNFamily.Type.SOP set automatically
##   • Default output port "out" of type SOP
##   • Cached GNGeoData with _prepare_geo() helper
##   • Input validation via _get_input_sop()
##   • Inline geometry stats preview (create_preview_control / update_preview_control)

# ─── Shared SOP Infrastructure ─────────────────────────────────────────────────

## Reusable output data object (created once, cleared each cook).
var _cached_geo: GNGeoData = null


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.SOP


## Ensures family is set even when subclass _init() doesn't call super().
func initialize(p_id: String) -> void:
	family = GNFamily.Type.SOP
	super.initialize(p_id)


## Default output port.  Override in subclass to add inputs or extra outputs.
func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Geometry output")


# ═══════════════════════════════════════════════════════════════════════════════
# Output Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Creates or clears the cached geometry data.
## Call at the top of _cook() to get a clean slate.
func _prepare_geo() -> GNGeoData:
	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()
	return _cached_geo


# ═══════════════════════════════════════════════════════════════════════════════
# Input Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Safely extracts a GNGeoData from the inputs array at [param port].
## Returns null if the port doesn't exist or the data is not GNGeoData.
func _get_input_sop(inputs: Array[GNData], port: int = 0) -> GNGeoData:
	if port < inputs.size() and inputs[port] is GNGeoData:
		return inputs[port] as GNGeoData
	return null


## Validates that port 0 has valid geometry. Returns the GNGeoData or null.
## Convenience for filter SOPs that require geometry on their first input.
func _require_input_geo(inputs: Array[GNData]) -> GNGeoData:
	var geo := _get_input_sop(inputs, 0)
	if geo == null or not geo.has_geometry():
		return null
	return geo


func update_preview_control(control: Control) -> void:
	if control is Label:
		(control as Label).text = cached_output.get_preview_text() if cached_output != null else ""


## Shared 3D scene nodes for geometry display.
static var _viewer_camera: Camera3D = null
static var _viewer_light: DirectionalLight3D = null
static var _viewer_gizmo: Node3D = null
static var _viewer_mesh_instance: MeshInstance3D = null
static var _viewer_env_node: WorldEnvironment = null

## Per-node viewer orbit state.
var _viewer_orbit_yaw: float = 45.0
var _viewer_orbit_pitch: float = -30.0
var _viewer_orbit_distance: float = 3.0
var _viewer_orbit_state: Dictionary = {}
var _viewer_wireframe: bool = false


static func _ensure_viewer_scene() -> void:
	if _viewer_camera != null:
		return
	_viewer_camera = Camera3D.new()
	_viewer_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_viewer_camera.fov = 45.0

	_viewer_light = DirectionalLight3D.new()
	_viewer_light.rotation_degrees = Vector3(-45, 30, 0)

	_viewer_mesh_instance = MeshInstance3D.new()

	_viewer_gizmo = GNViewerRenderHelpers._create_axis_gizmo()

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.12)
	env.ambient_light_color = Color(0.2, 0.2, 0.25)
	env.ambient_light_energy = 0.5
	_viewer_env_node = WorldEnvironment.new()
	_viewer_env_node.environment = env


static func _reparent_viewer_nodes(vp: SubViewport) -> void:
	for node in [_viewer_camera, _viewer_light, _viewer_mesh_instance, _viewer_gizmo, _viewer_env_node]:
		if node.get_parent() != vp:
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			vp.add_child(node)


func render_for_viewer(viewer) -> void:
	if cached_output is GNGeoData:
		var geo: GNGeoData = cached_output as GNGeoData
		if geo.mesh != null:
			_ensure_viewer_scene()
			var vp: SubViewport = viewer.get_3d_viewport()
			_reparent_viewer_nodes(vp)
			GNViewerRenderHelpers.apply_orbit_camera(
				_viewer_camera, _viewer_orbit_yaw, _viewer_orbit_pitch, _viewer_orbit_distance)
			GNViewerRenderHelpers.update_gizmo_scale(_viewer_gizmo, _viewer_orbit_distance)
			GNViewerRenderHelpers.render_sop(vp, _viewer_mesh_instance, geo.mesh, _viewer_wireframe)
			viewer.set_info_bar("%d verts" % geo.vertex_count)
			return
	viewer.set_info("No SOP output", "")


func toggle_viewer_wireframe() -> void:
	_viewer_wireframe = not _viewer_wireframe


func handle_viewer_input(event: InputEvent, _local_pos: Vector2) -> bool:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_viewer_orbit_state["dragging"] = mb.pressed
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_viewer_orbit_distance = maxf(_viewer_orbit_distance * 0.9, 0.5)
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_viewer_orbit_distance = minf(_viewer_orbit_distance * 1.1, 50.0)
			return true
	if event is InputEventMouseMotion and _viewer_orbit_state.get("dragging", false):
		var mm: InputEventMouseMotion = event
		_viewer_orbit_yaw = fmod(_viewer_orbit_yaw + mm.relative.x * 0.5, 360.0)
		_viewer_orbit_pitch = clampf(_viewer_orbit_pitch - mm.relative.y * 0.5, -89.0, 89.0)
		return true
	return false



