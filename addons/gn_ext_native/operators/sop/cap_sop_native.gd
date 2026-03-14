class_name CapSOPNative
extends GNSopBase
## Native-accelerated hole capping — delegates to GNNativeCapSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "cap"
	node_description = "Close open boundary holes with triangle fan caps — native C++ accelerated."
	if ClassDB.class_exists("GNNativeCapSop"):
		_processor = ClassDB.instantiate("GNNativeCapSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry with holes")
	add_output("out", GNFamily.Type.SOP, "Capped geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("cap_all", true, "Cap All Holes", ""))
	add_parameter(GNParameter.create_bool("flip_cap_normals", false, "Flip Cap Normals", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if in_geo == null or not in_geo.has_geometry():
		return null

	var geo := _prepare_geo()
	var flip: bool = get_param_value("flip_cap_normals")
	var new_mesh: ArrayMesh = in_geo.mesh.duplicate() as ArrayMesh

	if _processor and get_param_value("cap_all"):
		# Collect all positions and indices
		var all_pos := PackedVector3Array()
		var all_idx := PackedInt32Array()
		for s in range(new_mesh.get_surface_count()):
			var arrays: Array = new_mesh.surface_get_arrays(s)
			if arrays[Mesh.ARRAY_VERTEX] == null:
				continue
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()
			var base: int = all_pos.size()
			all_pos.append_array(verts)
			if indices.is_empty():
				for i in range(verts.size()):
					all_idx.append(base + i)
			else:
				for idx in indices:
					all_idx.append(base + idx)

		var result: Dictionary = _processor.process(all_pos, all_idx, flip)
		var cap_v: PackedVector3Array = result.get("positions", PackedVector3Array())
		var cap_n: PackedVector3Array = result.get("normals", PackedVector3Array())
		if not cap_v.is_empty():
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = cap_v
			arrays[Mesh.ARRAY_NORMAL] = cap_n
			new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	geo.set_mesh(new_mesh)
	return geo
