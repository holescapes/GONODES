class_name RenderPOP
extends GNPopBase
## Renders particles as a point cloud or billboards into a COMP scene.
## Bridge: reads POP SSBO → outputs GNCompBase-compatible scene node.

var _multi_mesh: MultiMesh = null
var _mesh_instance: MultiMeshInstance3D = null
var _scene_node: Node3D = null


func _init() -> void:
	super._init()
	node_type = "render"
	family = GNFamily.Type.COMP  # Outputs to COMP chain for RenderTOP


func initialize(p_id: String) -> void:
	family = GNFamily.Type.COMP
	super.initialize(p_id)


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input", "Pop")
	add_output("out", GNFamily.Type.COMP, "Renderable COMP output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("point_size", 0.05,
		0.001, 10.0, 0.001, "Point Size", "Base billboard quad size"))
	add_parameter(GNParameter.create_bool("use_pscale", true, "Use pscale",
		"Multiply point_size by particle pscale attribute"))
	add_parameter(GNParameter.create_bool("billboard", true, "Billboard",
		"Face camera (billboard quads)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var pd: GNParticleData = null
	if inputs.size() > 0 and inputs[0] is GNParticleData:
		pd = inputs[0] as GNParticleData
	if pd == null or not pd.has_particles():
		return null

	# CPU readback for positions + pscale
	var positions: PackedVector3Array = pd.read_positions()
	var pscales: PackedFloat32Array = pd.read_float_attrib("pscale") if get_param_value("use_pscale") else PackedFloat32Array()
	var count: int = positions.size()
	if count == 0:
		return null

	var base_size: float = get_param_value("point_size")
	var use_pscale: bool = get_param_value("use_pscale")
	var max_extent := 0.0
	var aabb_min := Vector3(INF, INF, INF)
	var aabb_max := Vector3(-INF, -INF, -INF)

	# Build MultiMesh
	if _multi_mesh == null:
		_multi_mesh = MultiMesh.new()
		_multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 1.0)
		_multi_mesh.mesh = quad
	_multi_mesh.instance_count = count

	for i in range(count):
		var xform := Transform3D.IDENTITY
		xform.origin = positions[i]
		var s: float = base_size
		if use_pscale and pscales.size() > i:
			s *= pscales[i]
		s = maxf(s, 0.0)
		xform.basis = Basis().scaled(Vector3(s, s, s))
		_multi_mesh.set_instance_transform(i, xform)
		aabb_min = aabb_min.min(positions[i])
		aabb_max = aabb_max.max(positions[i])
		max_extent = maxf(max_extent, s)

	var pad := Vector3.ONE * max_extent
	_multi_mesh.custom_aabb = AABB(aabb_min - pad, aabb_max - aabb_min + pad * 2.0)

	# Ensure scene node exists
	if _mesh_instance == null:
		_mesh_instance = MultiMeshInstance3D.new()
		_scene_node = _mesh_instance
	_mesh_instance.multimesh = _multi_mesh
	_apply_billboard(bool(get_param_value("billboard")))

	# Return the point cloud as COMP data so RenderTOP can place it in the scene.
	var out := GNCompData.new()
	out.scene_node = _scene_node
	out.scene_label = "Point cloud"
	out.valid = true
	return out


## Point Size and pscale live in the instance scale. Godot billboards drop
## that scale unless keep_scale is on, which is why those params did nothing.
func _apply_billboard(enabled: bool) -> void:
	var mat := _mesh_instance.material_override as StandardMaterial3D
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh_instance.material_override = mat
	mat.billboard_keep_scale = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if enabled else BaseMaterial3D.BILLBOARD_DISABLED


## Provides the scene node for RenderTOP to adopt.
func get_scene_node() -> Node3D:
	return _scene_node


func _cook_cpu(inputs: Array[GNData]) -> GNData:
	# RenderPOP already uses CPU readback (read_positions/read_float_attrib)
	# which handles both GPU and CPU particle data transparently.
	return _cook(inputs)


## COMP-style preview: scene node info (not particle count).
func update_preview_control(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		if _scene_node != null:
			var vis: String = "visible" if _scene_node.visible else "hidden"
			label.text = "%s\n%s" % [_scene_node.get_class(), vis]
		else:
			label.text = "no node"
