class_name InstanceSOPNative
extends GNSopBase
## Native-accelerated particle instancing — delegates to GNNativeInstancePop (C++).
## Consumes POP data but outputs SOP geometry (Rule 25.28).

var _processor: RefCounted = null


func _init() -> void:
	super._init()
	node_type = "instance_native"
	node_description = "Copy SOP geometry onto each particle — native C++ accelerated."
	if ClassDB.class_exists("GNNativeInstancePop"):
		_processor = ClassDB.instantiate("GNNativeInstancePop")


func _init_ports() -> void:
	add_input("pop_in", GNFamily.Type.POP, false, "Particle input", "POP")
	add_input("geo_in", GNFamily.Type.SOP, false, "Instance geometry", "Geometry")
	add_output("out", GNFamily.Type.SOP, "Instanced geometry output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("max_instances", 10000,
		1, 100000, "Max Instances", "Maximum instances to generate"))
	add_parameter(GNParameter.create_bool("use_pscale", true, "Use pscale",
		"Scale instances by particle pscale attribute"))
	add_parameter(GNParameter.create_bool("use_color", true, "Use Color",
		"Apply particle color to instance vertex colors"))


func _cook(inputs: Array[GNData]) -> GNData:
	var pd: GNParticleData = inputs[0] as GNParticleData if inputs.size() > 0 and inputs[0] is GNParticleData else null
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
	var use_color: bool = get_param_value("use_color")
	var max_inst: int = get_param_value("max_instances")
	var count: int = mini(positions.size(), max_inst)
	if count == 0:
		return null

	# Get source geometry arrays from first surface
	var src_arrays: Array = geo.mesh.surface_get_arrays(0)
	var src_verts: PackedVector3Array = src_arrays[Mesh.ARRAY_VERTEX] if src_arrays[Mesh.ARRAY_VERTEX] else PackedVector3Array()
	var src_normals: PackedVector3Array = src_arrays[Mesh.ARRAY_NORMAL] if src_arrays[Mesh.ARRAY_NORMAL] else PackedVector3Array()
	var src_indices: PackedInt32Array = src_arrays[Mesh.ARRAY_INDEX] if src_arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()

	if src_verts.is_empty() or not _processor:
		return null

	# Trim to max_instances
	var pos_trimmed := positions
	var psc_trimmed := pscales
	if positions.size() > max_inst:
		pos_trimmed = positions.slice(0, max_inst)
		if psc_trimmed.size() > max_inst:
			psc_trimmed = pscales.slice(0, max_inst)

	var result: Dictionary = _processor.process(src_verts, src_normals, src_indices,
		pos_trimmed, psc_trimmed)

	var out_v: PackedVector3Array = result.get("positions", PackedVector3Array())
	if out_v.is_empty():
		return null

	var out_geo := GNGeoData.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_v
	if result.has("normals") and not result["normals"].is_empty():
		arrays[Mesh.ARRAY_NORMAL] = result["normals"]
	if result.has("indices") and not result["indices"].is_empty():
		arrays[Mesh.ARRAY_INDEX] = result["indices"]

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out_geo.set_mesh(mesh)
	return out_geo
