class_name SubdivideSOP
extends GNSopBase
## Subdivides input geometry by splitting each triangle into 4.
## Useful for adding detail before noise displacement.


func _init() -> void:
	node_type = "subdivide"
	node_description = "Subdivide triangles into 4 sub-triangles."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Subdivided geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("iterations", 1, 1, 4, "Iterations", "Number of subdivision passes"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if in_geo == null or not in_geo.has_geometry():
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var iterations: int = get_param_value("iterations")
	var current_mesh: ArrayMesh = in_geo.mesh

	for _iter in range(iterations):
		var new_mesh := ArrayMesh.new()
		for s in range(current_mesh.get_surface_count()):
			var prim: Mesh.PrimitiveType = current_mesh.surface_get_primitive_type(s)
			if prim != Mesh.PRIMITIVE_TRIANGLES:
				# Can only subdivide triangle meshes
				new_mesh.add_surface_from_arrays(prim, current_mesh.surface_get_arrays(s))
				continue

			var arrays: Array = current_mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

			# If no indices, create sequential indices
			if indices.is_empty():
				indices.resize(verts.size())
				for i in range(verts.size()):
					indices[i] = i

			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)

			# Midpoint cache to avoid duplicate vertices
			var midpoint_cache: Dictionary = {}
			var new_idx: int = 0

			for tri in range(indices.size() / 3):
				var i0: int = indices[tri * 3]
				var i1: int = indices[tri * 3 + 1]
				var i2: int = indices[tri * 3 + 2]

				# Original vertices
				var v0: Vector3 = verts[i0]
				var v1: Vector3 = verts[i1]
				var v2: Vector3 = verts[i2]

				# Midpoints
				var m01: Vector3 = (v0 + v1) * 0.5
				var m12: Vector3 = (v1 + v2) * 0.5
				var m20: Vector3 = (v2 + v0) * 0.5

				# UVs (if available)
				var uv0 := Vector2.ZERO
				var uv1 := Vector2.ZERO
				var uv2 := Vector2.ZERO
				var uvm01 := Vector2.ZERO
				var uvm12 := Vector2.ZERO
				var uvm20 := Vector2.ZERO
				if not uvs.is_empty():
					uv0 = uvs[i0]
					uv1 = uvs[i1]
					uv2 = uvs[i2]
					uvm01 = (uv0 + uv1) * 0.5
					uvm12 = (uv1 + uv2) * 0.5
					uvm20 = (uv2 + uv0) * 0.5

				# Emit 4 sub-triangles
				_add_tri(st, v0, m01, m20, uv0, uvm01, uvm20)
				_add_tri(st, m01, v1, m12, uvm01, uv1, uvm12)
				_add_tri(st, m20, m12, v2, uvm20, uvm12, uv2)
				_add_tri(st, m01, m12, m20, uvm01, uvm12, uvm20)

			st.generate_normals()
			st.generate_tangents()
			st.commit(new_mesh)

		current_mesh = new_mesh

	_cached_geo.set_mesh(current_mesh)
	return _cached_geo


func _add_tri(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3,
		uv0: Vector2, uv1: Vector2, uv2: Vector2) -> void:
	st.set_uv(uv0)
	st.add_vertex(v0)
	st.set_uv(uv1)
	st.add_vertex(v1)
	st.set_uv(uv2)
	st.add_vertex(v2)
