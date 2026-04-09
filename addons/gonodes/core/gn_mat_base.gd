class_name GNMatBase
extends GNNode
## Base class for all MAT (Material Operator) family operators.
##
## Provides:
##   • family = GNFamily.Type.MAT set automatically
##   • Default output port "out" of type MAT
##   • Cached GNMaterialData with _prepare_material() helper
##   • Inline label preview (create_preview_control / update_preview_control)

# ─── Shared MAT Infrastructure ─────────────────────────────────────────────────

## Reusable output data object (created once, updated each cook).
var _cached_mat_data: GNMaterialData = null


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.MAT


## Ensures family is set even when subclass _init() doesn't call super().
func initialize(p_id: String) -> void:
	family = GNFamily.Type.MAT
	super.initialize(p_id)


## Default output port.  Override in subclass to add inputs or extra outputs.
func _init_ports() -> void:
	add_output("out", GNFamily.Type.MAT, "Material output")


# ═══════════════════════════════════════════════════════════════════════════════
# Output Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Creates the cached material data if it doesn't exist.
## Call at the top of _cook() to get a reusable output container.
func _prepare_output() -> GNMaterialData:
	if _cached_mat_data == null:
		_cached_mat_data = GNMaterialData.new()
	return _cached_mat_data


func update_preview_control(control: Control) -> void:
	if control is Label:
		(control as Label).text = cached_output.get_preview_text() if cached_output != null else ""


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


func render_for_viewer(viewer) -> void:
	if cached_output is GNMaterialData:
		var mat_data: GNMaterialData = cached_output as GNMaterialData
		if mat_data.material != null:
			_ensure_viewer_scene()
			var vp: SubViewport = viewer.get_3d_viewport()
			_reparent_viewer_nodes(vp)
			_viewer_sphere.material_override = mat_data.material
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			viewer.set_info_bar("Material: %s" % mat_data.material.get_class())
			return
	viewer.set_info("No MAT output", "")


static func _reparent_viewer_nodes(vp: SubViewport) -> void:
	for node in [_viewer_camera, _viewer_light, _viewer_sphere, _viewer_environment]:
		if node.get_parent() != vp:
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			vp.add_child(node)



