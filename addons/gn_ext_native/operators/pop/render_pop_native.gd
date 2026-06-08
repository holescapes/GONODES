class_name RenderPOPNative
extends GNPopBase
## Native-accelerated particle renderer — uses MultiMesh for display.
## Bridge: reads POP SSBO → outputs COMP scene node.

var _processor: RefCounted = null
var _multi_mesh: MultiMesh = null
var _mesh_instance: MultiMeshInstance3D = null
var _scene_node: Node3D = null


func _init() -> void:
	super._init()
	node_type = "render_native"
	node_description = "Render particles as point cloud or billboards — native C++ accelerated."
	family = GNFamily.Type.COMP
	if ClassDB.class_exists("GNNativeRenderPop"):
		_processor = ClassDB.instantiate("GNNativeRenderPop")


func initialize(p_id: String) -> void:
	family = GNFamily.Type.COMP
	super.initialize(p_id)


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input", "POP")
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

	# CPU readback
	var positions: PackedVector3Array = pd.read_positions()
	var pscales: PackedFloat32Array = pd.read_float_attrib("pscale") if get_param_value("use_pscale") else PackedFloat32Array()
	var count: int = positions.size()
	if count == 0:
		return null

	var base_size: float = get_param_value("point_size")

	# Compute transforms — delegate to C++ if available
	var transforms: Array
	if _processor:
		transforms = _processor.process(positions, pscales, base_size)
	else:
		transforms = []
		for i in range(count):
			var xform := Transform3D.IDENTITY
			xform.origin = positions[i]
			var s: float = base_size
			if pscales.size() > i:
				s *= pscales[i]
			xform.basis = xform.basis.scaled(Vector3(s, s, s))
			transforms.append(xform)

	# Build MultiMesh
	if _multi_mesh == null:
		_multi_mesh = MultiMesh.new()
		_multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 1.0)
		_multi_mesh.mesh = quad
	_multi_mesh.instance_count = count

	for i in range(count):
		_multi_mesh.set_instance_transform(i, transforms[i])

	if _mesh_instance == null:
		_mesh_instance = MultiMeshInstance3D.new()
		_scene_node = _mesh_instance
	_mesh_instance.multimesh = _multi_mesh

	if get_param_value("billboard") and _mesh_instance.material_override == null:
		var mat := StandardMaterial3D.new()
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mesh_instance.material_override = mat

	var out := GNData.new()
	out.valid = true
	return out


func get_scene_node() -> Node3D:
	return _scene_node


func update_preview_control(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		if _scene_node != null:
			var vis: String = "visible" if _scene_node.visible else "hidden"
			label.text = "POP Renderer (%s)" % vis
		else:
			label.text = "POP Renderer (no scene)"
