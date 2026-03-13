class_name InstancePOP
extends GNPopBase
## Copies SOP geometry onto each particle position.
## Bridge operator: reads POP SSBO → outputs GNGeoData (SOP) via CPU readback.

func _init() -> void:
	super._init()
	node_type = "instance"
	node_description = "Copy SOP geometry onto each particle. Outputs SOP geometry."


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input")
	add_input("geo_in", GNFamily.Type.SOP, false, "Instance geometry")
	add_output("out", GNFamily.Type.SOP, "Instanced geometry output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("max_instances", 10000,
		1, 100000, "Max Instances", "Maximum instances to generate (limits CPU load)"))
	add_parameter(GNParameter.create_bool("use_pscale", true, "Use pscale",
		"Scale instances by the particle pscale attribute"))
	add_parameter(GNParameter.create_bool("use_color", true, "Use Color",
		"Apply particle color attribute to instance vertex colors"))


func _cook(inputs: Array[GNData]) -> GNData:
	var pd := _get_input_pop(inputs, 0)
	if pd == null or not pd.has_particles():
		return null

	var geo: GNGeoData = null
	if inputs.size() > 1 and inputs[1] is GNGeoData:
		geo = inputs[1] as GNGeoData
	if geo == null or not geo.has_geometry():
		return null

	# CPU readback — positions + pscale
	var positions: PackedVector3Array = pd.read_positions()
	var pscales: PackedFloat32Array = pd.read_float_attrib("pscale") if get_param_value("use_pscale") else PackedFloat32Array()

	var max_inst: int = mini(get_param_value("max_instances"), positions.size())
	if max_inst <= 0:
		return null

	# Build instanced mesh via MultiMesh resource → then flatten to ArrayMesh
	var source_mesh: Mesh = geo.mesh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = source_mesh
	mm.instance_count = max_inst

	for i in range(max_inst):
		var xform := Transform3D.IDENTITY
		xform.origin = positions[i]
		if pscales.size() > i:
			var s: float = pscales[i]
			xform.basis = xform.basis.scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, xform)

	# Output as GNGeoData wrapping the MultiMesh's generated mesh
	var out := GNGeoData.new()
	# Store the MultiMesh reference for RenderTOP/COMP to use directly
	out.mesh = source_mesh
	out.point_attribs["_multimesh"] = mm
	out.point_attribs["_instance_count"] = max_inst
	out.vertex_count = max_inst
	return out
